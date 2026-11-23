from pathlib import Path
import numpy as np
import cv2

root = Path(r'e:/NiyyahTracker-mobile-app-ai/assets/splash')
assets = Path(r'e:/NiyyahTracker-mobile-app-ai/assets')


def max_side(img, max_dim=2048):
    h, w = img.shape[:2]
    if max(h, w) <= max_dim:
        return img
    scale = max_dim / max(h, w)
    nw, nh = int(w * scale), int(h * scale)
    return cv2.resize(img, (nw, nh), interpolation=cv2.INTER_AREA)


def checker_to_alpha(bgr, lum_min=200, sat_max=25):
    hsv = cv2.cvtColor(bgr, cv2.COLOR_BGR2HSV)
    _h, s, v = cv2.split(hsv)
    cand = ((v >= lum_min) & (s <= sat_max)).astype(np.uint8) * 255

    hgt, wdt = cand.shape
    mask = np.zeros((hgt + 2, wdt + 2), np.uint8)
    seeds = []
    for x in range(0, wdt, 8):
        if cand[0, x]:
            seeds.append((x, 0))
        if cand[hgt - 1, x]:
            seeds.append((x, hgt - 1))
    for y in range(0, hgt, 8):
        if cand[y, 0]:
            seeds.append((0, y))
        if cand[y, wdt - 1]:
            seeds.append((wdt - 1, y))

    fill_src = cand.copy()
    for (x, y) in seeds:
        if mask[y + 1, x + 1] == 0:
            cv2.floodFill(fill_src, mask, (x, y), 128, loDiff=0, upDiff=0, flags=4)
    bg = (mask[1:-1, 1:-1] > 0).astype(np.uint8) * 255
    bg = cv2.morphologyEx(bg, cv2.MORPH_CLOSE, np.ones((5, 5), np.uint8))

    dist = cv2.distanceTransform(255 - bg, cv2.DIST_L2, 3)
    alpha = np.clip(dist * 12.0, 0, 255).astype(np.uint8)
    alpha[bg > 0] = 0

    rgba = cv2.cvtColor(bgr, cv2.COLOR_BGR2BGRA)
    rgba[:, :, 3] = alpha
    return rgba


def logo_to_alpha(bgr):
    hsv = cv2.cvtColor(bgr, cv2.COLOR_BGR2HSV)
    _h, s, v = cv2.split(hsv)
    paper = ((v >= 210) & (s <= 45)).astype(np.uint8) * 255
    paper2 = ((v >= 190) & (s <= 30) & (v < 210)).astype(np.uint8) * 255
    paper = cv2.bitwise_or(paper, paper2)
    paper = cv2.morphologyEx(paper, cv2.MORPH_CLOSE, np.ones((3, 3), np.uint8))
    dist = cv2.distanceTransform(255 - paper, cv2.DIST_L2, 3)
    alpha = np.clip(dist * 18.0, 0, 255).astype(np.uint8)
    alpha[paper > 0] = 0
    rgba = cv2.cvtColor(bgr, cv2.COLOR_BGR2BGRA)
    rgba[:, :, 3] = alpha
    return rgba


jobs = [
    (root / 'mosque_arch_3d.png.jpg', root / 'mosque_arch_3d.png', 'checker'),
    (root / 'quran_rehal_3d.png.jpg', root / 'quran_rehal_3d.png', 'checker'),
    (root / 'mosque_arch_3d.png (2).jpg', root / 'lantern_3d.png', 'checker'),
    (assets / 'new-logo.jpg', root / 'basair_logo.png', 'logo'),
]

for src, dst, kind in jobs:
    print('processing', src.name, '->', dst.name)
    data = np.fromfile(str(src), dtype=np.uint8)
    bgr = cv2.imdecode(data, cv2.IMREAD_COLOR)
    print('  in', bgr.shape)
    bgr = max_side(bgr, 2048)
    rgba = logo_to_alpha(bgr) if kind == 'logo' else checker_to_alpha(bgr)
    a = rgba[:, :, 3]
    print(
        f'  out {rgba.shape} trans={(a == 0).sum()} '
        f'opaque={(a == 255).sum()} semi={((a > 0) & (a < 255)).sum()}'
    )
    ok, buf = cv2.imencode('.png', rgba)
    dst.write_bytes(buf.tobytes())
    print('  wrote', dst, dst.stat().st_size)

print('done')
