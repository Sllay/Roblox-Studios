"""Build labeled contact sheets from actual C0 renders; never generate imagery."""
import argparse
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

from .audit import sha256, write_json, valid_cache, validate_output


def contact_sheet(audit_dir: Path, report: dict, columns: list[tuple[str, str]], out: Path):
    width, height, label = 240, 270, 220
    sheet = Image.new("RGB", (label + width * len(columns), 70 + height * len(report["measurements"]) + 60), (28, 30, 34))
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.load_default(size=15)
    small = ImageFont.load_default(size=12)
    draw.text((14, 10), "C0: preserved GLBs / Blender Cycles CPU / review required", font=font, fill="white")
    for i, (_, title) in enumerate(columns):
        draw.text((label + i * width + 7, 42), title, font=font, fill="white")
    for row, (identifier, entry) in enumerate(report["measurements"].items()):
        y = 70 + row * height
        totals = entry["blender_measurements"]["totals"]
        draw.multiline_text((12, y + 25), identifier.replace("-", "\n", 2) +
                            f"\n\n{totals['triangles']:,} triangles\n{totals['vertices']:,} vertices\n{totals['uvCharts']} UV charts\n{totals['bones']} bones", font=small, fill="white", spacing=5)
        for column, (name, _) in enumerate(columns):
            source = audit_dir / identifier / name
            x = label + column * width
            if not source.exists():
                draw.text((x + 15, y + 100), "Not available", font=small, fill=(190, 190, 190))
                continue
            with Image.open(source) as image:
                image = image.convert("RGBA")
                image.thumbnail((width - 8, height - 16))
                background = Image.new("RGBA", image.size, (105, 108, 112, 255))
                background.alpha_composite(image)
                sheet.paste(background.convert("RGB"), (x + (width - image.width) // 2, y + 8))
    draw.text((12, sheet.height - 48), "Depth PNG: independently normalized per view; float32 metric buffers are separate. No concept ground-truth depth.", font=small, fill="white")
    draw.text((12, sheet.height - 27), "UV wire combines materials; overlapping legacy material atlases are not a shared-atlas overlap test. Pose is a generic probe.", font=small, fill="white")
    sheet.save(out)
    with Image.open(out) as image:
        image.verify()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--audit", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    report = json.loads((args.audit / "audit.json").read_text())
    if report.get("status") != "measured":
        raise ValueError("Complete all five read-only baseline measurements before comparison")
    for identifier, entry in report["measurements"].items():
        target = args.audit / identifier
        if not valid_cache(target):
            raise ValueError("Missing or modified baseline evidence: " + identifier)
        if json.loads((target / "metrics.json").read_text()) != entry["blender_measurements"]:
            raise ValueError("Baseline report disagrees with measured output: " + identifier)
    args.out = validate_output(args.out, allow_benchmark_docs=True)
    args.out.mkdir(parents=True, exist_ok=True)
    if any(args.out.iterdir()):
        raise ValueError("Use a new comparison output directory; preserve prior evidence")
    contact_sheet(args.audit, report, [("clay-front.png", "Clay front"), ("clay-right.png", "Clay profile"),
                  ("clay-three-quarter.png", "Clay three-quarter"), ("depth-right.png", "Depth profile"),
                  ("normal-right.png", "Normals profile")], args.out / "geometry.png")
    contact_sheet(args.audit, report, [("color-three-quarter.png", "Color three-quarter"), ("color-right.png", "Color profile"),
                  ("uv-checker.png", "UV checker"), ("uv-wire.png", "UV wire"),
                  ("pose-0.png", "Generic rig probe")], args.out / "color-uv-poses.png")
    write_json(args.out / "measurements.json", report)
    hashes = {}
    for path in sorted(args.audit.rglob("*")):
        if path.is_file() and not any(p.startswith(".") for p in path.relative_to(args.audit).parts):
            hashes[str(path.relative_to(args.audit))] = {"bytes":path.stat().st_size,"sha256":sha256(path)}
    write_json(args.out / "artifact-hashes.json", {"schema":1, "files":hashes,
               "scope":"Full raw outputs remain in the audit output directory; hashes permit exact verification of the measured run. Re-rendered Monte Carlo pixels can vary by Blender version/platform."})


if __name__ == "__main__":
    main()
