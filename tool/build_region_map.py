#!/usr/bin/env python3
"""Build the offline Ile-de-France map asset from OpenStreetMap data.

Temporary solution until the app uses a real map provider: the map shown on
the home page is drawn by flutter_map from a small JSON file bundled with the
app, so it needs no API key, no tile server and no network.

Usage (from the repository root):

    python3 tool/build_region_map.py [--cache DIR] [--out PATH]

The raw data comes from the free Overpass API (overpass-api.de) and is cached
in DIR (default: build/osm) so the processing can be re-run offline.
Data (c) OpenStreetMap contributors, ODbL: keep the attribution in the app.

Output format (version 1), all coordinates are integers scaled by 10^precision:
  roads:    {class: [line, ...]} with line = [x0, y0, dx1, dy1, dx2, dy2, ...]
            (first pair absolute, then deltas from the previous point)
  rivers:   [line, ...]
  boundary: [line, ...]
  places:   [[name, kind, x, y], ...]
  bounds:   [west, south, east, north] in degrees
"""

import argparse
import json
import math
import os
import urllib.parse
import urllib.request
from collections import defaultdict, deque

OVERPASS_URL = "https://overpass-api.de/api/interpreter"
REGION_RELATION_ID = 8649  # Ile-de-France
AREA_ID = 3_600_000_000 + REGION_RELATION_ID

ROAD_CLASSES = ["motorway", "trunk", "primary", "secondary", "tertiary"]

QUERIES = {
    "roads": f"""
[out:json][timeout:600];
area({AREA_ID})->.region;
way(area.region)["highway"~"^({'|'.join(ROAD_CLASSES)})$"];
out tags geom;
""",
    "other": f"""
[out:json][timeout:300];
area({AREA_ID})->.region;
(
  way(area.region)["waterway"="river"];
  node(area.region)["place"~"^(city|town)$"];
  relation({REGION_RELATION_ID});
);
out geom;
""",
}

PRECISION = 5
SCALE = 10**PRECISION
# Douglas-Peucker tolerance in metres. 3 m is below 2 px at zoom 16.
ROAD_TOLERANCE_M = 3.0
RIVER_TOLERANCE_M = 8.0
BOUNDARY_TOLERANCE_M = 30.0
# Long merged lines are never culled by the renderer, so keep them short.
MAX_POINTS_PER_LINE = 256

# Local equirectangular projection around Paris, good enough for simplifying.
M_PER_DEG_LAT = 110_540.0
M_PER_DEG_LON = 111_320.0 * math.cos(math.radians(48.85))


def fetch(name, cache_dir):
    path = os.path.join(cache_dir, f"{name}.json")
    if not os.path.exists(path):
        os.makedirs(cache_dir, exist_ok=True)
        body = urllib.parse.urlencode({"data": QUERIES[name]}).encode()
        request = urllib.request.Request(
            OVERPASS_URL,
            data=body,
            headers={"User-Agent": "osm-extract-script/1.0"},
        )
        print(f"Downloading {name} from Overpass...")
        with urllib.request.urlopen(request, timeout=900) as response:
            with open(path, "wb") as file:
                file.write(response.read())
    with open(path, encoding="utf-8") as file:
        return json.load(file)["elements"]


def geometry(element):
    return [(p["lon"], p["lat"]) for p in element.get("geometry") or [] if p]


def merge_lines(lines):
    """Chains lines sharing an endpoint to reduce the number of polylines."""
    ends = defaultdict(list)
    for index, line in enumerate(lines):
        ends[line[0]].append(index)
        ends[line[-1]].append(index)
    used = [False] * len(lines)

    def next_line(key):
        for index in ends[key]:
            if not used[index]:
                used[index] = True
                return lines[index]
        return None

    merged = []
    for index, line in enumerate(lines):
        if used[index]:
            continue
        used[index] = True
        chain = deque(line)
        while len(chain) < MAX_POINTS_PER_LINE:
            other = next_line(chain[-1])
            if other is None:
                break
            chain.extend(other[1:] if other[0] == chain[-1] else other[-2::-1])
        while len(chain) < MAX_POINTS_PER_LINE:
            other = next_line(chain[0])
            if other is None:
                break
            head = other[:-1] if other[-1] == chain[0] else other[:0:-1]
            chain.extendleft(reversed(head))
        merged.append(list(chain))
    return merged


def simplify(points, tolerance_m):
    """Iterative Douglas-Peucker in metres."""
    if len(points) < 3:
        return points
    xy = [(x * M_PER_DEG_LON, y * M_PER_DEG_LAT) for x, y in points]
    keep = [False] * len(points)
    keep[0] = keep[-1] = True
    stack = [(0, len(points) - 1)]
    while stack:
        start, end = stack.pop()
        (ax, ay), (bx, by) = xy[start], xy[end]
        dx, dy = bx - ax, by - ay
        length_sq = dx * dx + dy * dy
        farthest, max_dist = -1, tolerance_m
        for i in range(start + 1, end):
            px, py = xy[i]
            if length_sq == 0:
                dist = math.hypot(px - ax, py - ay)
            else:
                t = max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / length_sq))
                dist = math.hypot(px - (ax + t * dx), py - (ay + t * dy))
            if dist > max_dist:
                farthest, max_dist = i, dist
        if farthest != -1:
            keep[farthest] = True
            stack.append((start, farthest))
            stack.append((farthest, end))
    return [p for p, kept in zip(points, keep) if kept]


def encode(points):
    """Quantizes and delta-encodes a line; returns None if it collapses."""
    quantized = []
    for x, y in points:
        q = (round(x * SCALE), round(y * SCALE))
        if not quantized or quantized[-1] != q:
            quantized.append(q)
    if len(quantized) < 2:
        return None
    encoded, previous = [], (0, 0)
    for q in quantized:
        encoded += [q[0] - previous[0], q[1] - previous[1]]
        previous = q
    return encoded


def encode_lines(lines, tolerance_m):
    result = []
    for line in merge_lines(lines):
        encoded = encode(simplify(line, tolerance_m))
        if encoded:
            result.append(encoded)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--cache", default="build/osm")
    parser.add_argument("--out", default="assets/maps/ile_de_france.json")
    args = parser.parse_args()

    roads_by_class = defaultdict(list)
    for element in fetch("roads", args.cache):
        line = geometry(element)
        if len(line) >= 2:
            roads_by_class[element["tags"]["highway"]].append(line)

    rivers, boundary, places = defaultdict(list), [], []
    for element in fetch("other", args.cache):
        tags = element.get("tags", {})
        if element["type"] == "way":
            line = geometry(element)
            if len(line) >= 2:
                rivers[tags.get("name", "")].append(line)
        elif element["type"] == "node" and tags.get("name"):
            places.append(
                [
                    tags["name"],
                    tags["place"],
                    round(element["lon"] * SCALE),
                    round(element["lat"] * SCALE),
                ]
            )
        elif element["type"] == "relation":
            for member in element.get("members", []):
                if member["type"] == "way" and member.get("role") == "outer":
                    line = geometry(member)
                    if len(line) >= 2:
                        boundary.append(line)

    all_points = [p for line in boundary for p in line]
    bounds = [
        round(min(p[0] for p in all_points), 4),
        round(min(p[1] for p in all_points), 4),
        round(max(p[0] for p in all_points), 4),
        round(max(p[1] for p in all_points), 4),
    ]
    places.sort(key=lambda place: (place[1] != "city", place[0]))

    output = {
        "version": 1,
        "name": "Île-de-France",
        "attribution": "OpenStreetMap contributors",
        "precision": PRECISION,
        "bounds": bounds,
        "roads": {
            road_class: encode_lines(roads_by_class[road_class], ROAD_TOLERANCE_M)
            for road_class in ROAD_CLASSES
        },
        "rivers": [
            line
            for lines in rivers.values()
            for line in encode_lines(lines, RIVER_TOLERANCE_M)
        ],
        "boundary": encode_lines(boundary, BOUNDARY_TOLERANCE_M),
        "places": places,
    }

    os.makedirs(os.path.dirname(args.out) or ".", exist_ok=True)
    with open(args.out, "w", encoding="utf-8") as file:
        json.dump(output, file, ensure_ascii=False, separators=(",", ":"))

    for road_class, lines in output["roads"].items():
        points = sum(len(line) // 2 for line in lines)
        print(f"{road_class:>10}: {len(lines):6} lines {points:7} points")
    print(f"    rivers: {len(output['rivers']):6} lines")
    print(f"  boundary: {len(output['boundary']):6} lines")
    print(f"    places: {len(places):6}")
    print(f"{args.out}: {os.path.getsize(args.out) / 1e6:.2f} MB")


if __name__ == "__main__":
    main()
