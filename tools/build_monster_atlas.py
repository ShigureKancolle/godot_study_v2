# coding=utf-8
"""只读 PNG 透明通道，输出逐帧 AtlasTexture 区域；不修改、不重绘源图像。需要 Pillow、NumPy。"""

import json
from pathlib import Path

import numpy as np
from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "client/Prefab/Role/anim/monsters"


def components(path: Path):
    """按透明区域分离角色轮廓，保留独立飞溅和细小装饰供后续归属。"""
    with Image.open(path) as image:
        mask = np.array(image.getchannel("A")) > 24
    height, width = mask.shape
    pending = bytearray(mask.tobytes())
    result = []
    for seed in np.flatnonzero(mask):
        seed = int(seed)
        if not pending[seed]:
            continue
        pending[seed] = 0
        stack = [seed]
        count, left, top, right, bottom = 0, width, height, 0, 0
        while stack:
            current = stack.pop()
            y, x = divmod(current, width)
            count += 1
            left, top, right, bottom = min(left, x), min(top, y), max(right, x + 1), max(bottom, y + 1)
            for neighbor, valid in ((current - 1, x > 0), (current + 1, x + 1 < width), (current - width, y > 0), (current + width, y + 1 < height)):
                if valid and pending[neighbor]:
                    pending[neighbor] = 0
                    stack.append(neighbor)
        result.append([count, left, top, right, bottom])
    return sorted(result, reverse=True), width, height


def build(path: Path):
    """要求恰有八十个主要轮廓，按十行八列排序后生成独立帧区域。"""
    parts, width, height = components(path)
    if len(parts) < 80 or parts[79][0] < 1000 or (len(parts) > 80 and parts[80][0] > parts[79][0] * 0.25):
        raise ValueError(f"{path.name}: 不能可靠识别八十个角色轮廓，需要检查图集")
    ordered = sorted(parts[:80], key=lambda item: item[2] + item[4])
    bodies = []
    for row in range(10):
        bodies.extend(sorted(ordered[row * 8:row * 8 + 8], key=lambda item: item[1] + item[3]))
    bounds = [item[1:].copy() for item in bodies]
    centers = [((item[1] + item[3]) / 2, (item[2] + item[4]) / 2) for item in bodies]
    for item in parts[80:]:
        if item[0] < 8:
            continue
        x, y = (item[1] + item[3]) / 2, (item[2] + item[4]) / 2
        index = min(range(80), key=lambda i: (centers[i][0] - x) ** 2 + (centers[i][1] - y) ** 2)
        left, top, right, bottom = bounds[index]
        bounds[index] = [min(left, item[1]), min(top, item[2]), max(right, item[3]), max(bottom, item[4])]
    regions = []
    for left, top, right, bottom in bounds:
        left, top, right, bottom = max(0, left - 2), max(0, top - 2), min(width, right + 2), min(height, bottom + 2)
        regions.append([left, top, right - left, bottom - top])
    canvas = [max(region[2] for region in regions) + 8, max(region[3] for region in regions) + 8]
    metadata = {"_comment": "原始图片保持不变；逐帧矩形和统一底部对齐画布供 AtlasTexture 使用", "texture_size": [width, height], "canvas_size": canvas, "regions": regions}
    path.with_suffix(".atlas.json").write_text(json.dumps(metadata, ensure_ascii=False, separators=(",", ":")) + "\n", encoding="utf-8")
    print(f"{path.name}: 80 帧，画布 {canvas}")


if __name__ == "__main__":
    for source in sorted(ASSETS.glob("*.png")):
        build(source)
