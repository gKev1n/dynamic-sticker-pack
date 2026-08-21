#!/usr/bin/env python3
"""移除 GIF 中与画面边缘连通的低纹理近白背景。

该脚本适用于纯白或近白背景，不是通用语义抠图模型。白色主体必须先用完整动画试跑，
并在高饱和彩色底上检查后再批量处理。
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Iterable

try:
    import numpy as np
    from PIL import Image
    from scipy import ndimage
except ImportError as exc:  # pragma: no cover - 依赖缺失时给出可执行提示
    raise SystemExit(
        "缺少透明背景脚本依赖。请在获准后安装 Pillow、NumPy 和 SciPy。"
    ) from exc


SUPPORTED_EXTENSIONS = {".gif"}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="移除 GIF 中与边缘连通的近白背景，并保留无限循环。"
    )
    parser.add_argument(
        "inputs",
        nargs="+",
        help="一个或多个 GIF 文件或目录；目录只扫描当前层。",
    )
    parser.add_argument("--output-dir", required=True, help="透明 GIF 输出目录。")
    parser.add_argument(
        "--threshold",
        type=int,
        default=245,
        help="背景候选像素的最低 RGB 通道值，默认 245。",
    )
    parser.add_argument(
        "--neutral-limit",
        type=int,
        default=14,
        help="背景候选像素的最大通道差，默认 14。",
    )
    parser.add_argument(
        "--gradient-limit",
        type=float,
        default=4.0,
        help="背景候选像素的最大高斯梯度，默认 4.0。",
    )
    parser.add_argument(
        "--gradient-sigma",
        type=float,
        default=1.0,
        help="梯度检测的高斯 sigma，默认 1.0。",
    )
    parser.add_argument(
        "--edge-threshold",
        type=int,
        default=None,
        help="一像素边缘清理的最低 RGB 通道值，默认 threshold-12。",
    )
    parser.add_argument(
        "--edge-neutral-limit",
        type=int,
        default=None,
        help="一像素边缘清理的最大通道差，默认 neutral-limit+5。",
    )
    parser.add_argument(
        "--grow",
        type=int,
        default=1,
        help="背景边缘清理像素数，默认 1。",
    )
    parser.add_argument(
        "--overwrite",
        action="store_true",
        help="允许覆盖目标文件；只有用户明确授权替换时才使用。",
    )
    parser.add_argument("--json", action="store_true", help="以 JSON 输出结果。")
    return parser.parse_args()


def validate_args(args: argparse.Namespace) -> None:
    for name in ("threshold", "neutral_limit"):
        value = getattr(args, name)
        if not 0 <= value <= 255:
            raise SystemExit(f"{name} 必须在 0–255 之间。")
    if args.gradient_limit < 0 or args.gradient_sigma <= 0:
        raise SystemExit("gradient-limit 必须非负，gradient-sigma 必须大于 0。")
    if args.grow < 0:
        raise SystemExit("grow 不能为负数。")

    if args.edge_threshold is None:
        args.edge_threshold = max(0, args.threshold - 12)
    if args.edge_neutral_limit is None:
        args.edge_neutral_limit = min(255, args.neutral_limit + 5)


def collect_inputs(entries: Iterable[str]) -> list[Path]:
    files: list[Path] = []
    for raw_entry in entries:
        entry = Path(raw_entry).expanduser().resolve()
        if not entry.exists():
            raise SystemExit(f"输入不存在：{entry}")
        if entry.is_dir():
            files.extend(
                item.resolve()
                for item in sorted(entry.iterdir())
                if item.is_file() and item.suffix.lower() in SUPPORTED_EXTENSIONS
            )
        elif entry.suffix.lower() in SUPPORTED_EXTENSIONS:
            files.append(entry)
        else:
            raise SystemExit(f"不支持的输入格式：{entry}")

    unique_files = sorted(set(files))
    if not unique_files:
        raise SystemExit("没有找到 GIF 输入文件。")
    return unique_files


def background_mask(rgb: np.ndarray, args: argparse.Namespace) -> np.ndarray:
    minimum = rgb.min(axis=2)
    channel_range = rgb.max(axis=2) - minimum
    gray = rgb.astype(np.float32).mean(axis=2)
    gradient = ndimage.gaussian_gradient_magnitude(
        gray, sigma=args.gradient_sigma
    )

    candidate = (
        (minimum >= args.threshold)
        & (channel_range <= args.neutral_limit)
        & (gradient <= args.gradient_limit)
    )
    seed = np.zeros(candidate.shape, dtype=bool)
    seed[0, :] = candidate[0, :]
    seed[-1, :] = candidate[-1, :]
    seed[:, 0] = candidate[:, 0]
    seed[:, -1] = candidate[:, -1]
    background = ndimage.binary_propagation(seed, mask=candidate)

    if args.grow:
        edge_candidate = (
            (minimum >= args.edge_threshold)
            & (channel_range <= args.edge_neutral_limit)
        )
        background |= (
            ndimage.binary_dilation(background, iterations=args.grow)
            & edge_candidate
        )
    return background


def make_transparent(
    source: Path,
    destination: Path,
    args: argparse.Namespace,
) -> dict[str, object]:
    frames: list[Image.Image] = []
    durations: list[int] = []
    transparent_ratios: list[float] = []

    with Image.open(source) as image:
        input_frame_count = getattr(image, "n_frames", 1)
        default_duration = int(image.info.get("duration", 67))
        for index in range(input_frame_count):
            image.seek(index)
            frame = image.convert("RGBA")
            rgb = np.asarray(frame.convert("RGB"), dtype=np.uint8)
            mask = background_mask(rgb, args)

            rgba = np.asarray(frame, dtype=np.uint8).copy()
            rgba[:, :, 3] = np.where(mask, 0, 255).astype(np.uint8)
            frames.append(Image.fromarray(rgba, "RGBA"))
            durations.append(int(image.info.get("duration", default_duration)))
            transparent_ratios.append(float(mask.mean()))

    frames[0].save(
        destination,
        save_all=True,
        append_images=frames[1:],
        duration=durations,
        loop=0,
        disposal=2,
        optimize=True,
    )

    transparent_frame_count = 0
    with Image.open(destination) as check:
        output_frame_count = getattr(check, "n_frames", 1)
        loop_count = int(check.info.get("loop", 0))
        for index in range(output_frame_count):
            check.seek(index)
            alpha = np.asarray(check.convert("RGBA"), dtype=np.uint8)[:, :, 3]
            if np.any(alpha == 0):
                transparent_frame_count += 1

    if output_frame_count != input_frame_count:
        raise RuntimeError(
            f"输出帧数变化：{source.name} {input_frame_count} -> {output_frame_count}"
        )
    if transparent_frame_count == 0:
        raise RuntimeError(f"输出没有透明像素：{destination}")

    digest = hashlib.sha256(destination.read_bytes()).hexdigest().upper()
    return {
        "input": str(source),
        "output": str(destination),
        "frames": output_frame_count,
        "transparent_frames": transparent_frame_count,
        "loop_count": loop_count,
        "infinite_loop": loop_count == 0,
        "mean_transparent_ratio": round(
            sum(transparent_ratios) / len(transparent_ratios), 4
        ),
        "min_transparent_ratio": round(min(transparent_ratios), 4),
        "max_transparent_ratio": round(max(transparent_ratios), 4),
        "megabytes": round(destination.stat().st_size / (1024 * 1024), 3),
        "sha256": digest,
    }


def main() -> int:
    args = parse_args()
    validate_args(args)
    inputs = collect_inputs(args.inputs)
    output_dir = Path(args.output_dir).expanduser().resolve()
    output_dir.mkdir(parents=True, exist_ok=True)

    plans = [(source, output_dir / source.name) for source in inputs]
    destinations = [destination for _, destination in plans]
    if len(set(destinations)) != len(destinations):
        raise SystemExit("多个输入会生成同名输出。")
    if not args.overwrite:
        existing = next(
            (destination for destination in destinations if destination.exists()),
            None,
        )
        if existing is not None:
            raise SystemExit(f"拒绝覆盖已有文件：{existing}")

    results: list[dict[str, object]] = []
    for source, destination in plans:
        results.append(make_transparent(source, destination, args))

    if args.json:
        print(json.dumps(results, ensure_ascii=False, indent=2))
    else:
        for result in results:
            print(
                f"{result['output']} | {result['frames']} frames | "
                f"{result['megabytes']} MiB | transparent "
                f"{result['transparent_frames']}/{result['frames']}"
            )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
