"""
Removes background from alert spritesheets using edge flood-fill.
Only removes pixels reachable from the image border that match the background color.
This preserves interior content (text, icons) even if they are white/light.
Usage: python tools/remove_bg_alerts.py
"""
from PIL import Image
import os
from collections import deque

ASSETS_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "alerts")
THRESHOLD = 40  # color distance from seed pixel to be considered background


def color_dist(a, b):
    return max(abs(int(a[0]) - int(b[0])),
               abs(int(a[1]) - int(b[1])),
               abs(int(a[2]) - int(b[2])))


def flood_fill_transparent(img: Image.Image) -> Image.Image:
    img = img.convert("RGBA")
    pixels = img.load()
    w, h = img.size

    # Seed color = average of the 4 corner pixels
    corners = [pixels[0, 0], pixels[w-1, 0], pixels[0, h-1], pixels[w-1, h-1]]
    seed_r = sum(c[0] for c in corners) // 4
    seed_g = sum(c[1] for c in corners) // 4
    seed_b = sum(c[2] for c in corners) // 4
    seed = (seed_r, seed_g, seed_b)

    visited = [[False] * h for _ in range(w)]
    queue = deque()

    # Seed from all 4 edges
    for x in range(w):
        queue.append((x, 0))
        queue.append((x, h - 1))
    for y in range(h):
        queue.append((0, y))
        queue.append((w - 1, y))

    while queue:
        x, y = queue.popleft()
        if x < 0 or x >= w or y < 0 or y >= h:
            continue
        if visited[x][y]:
            continue
        visited[x][y] = True
        r, g, b, a = pixels[x, y]
        if a == 0:
            continue
        if color_dist((r, g, b), seed) > THRESHOLD:
            continue
        pixels[x, y] = (r, g, b, 0)
        queue.append((x+1, y))
        queue.append((x-1, y))
        queue.append((x, y+1))
        queue.append((x, y-1))

    return img


def process_image(path: str) -> None:
    img = Image.open(path)
    result = flood_fill_transparent(img)
    result.save(path)
    print(f"  saved: {os.path.basename(path)}")


def main() -> None:
    files = [f for f in os.listdir(ASSETS_DIR) if f.startswith("alert_") and f.endswith(".png")]
    if not files:
        print("No alert_*.png files found in assets/alerts/")
        return
    for f in sorted(files):
        full = os.path.join(ASSETS_DIR, f)
        print(f"Processing {f}...")
        process_image(full)
    print("Done.")


if __name__ == "__main__":
    main()
