"""C0 reproducible, read-only baseline audit. Never runs legacy animal writers.

python -m tools.creature_factory.next audit --out dist/creature-next/c0 --render
"""
from __future__ import annotations

import argparse
from contextlib import contextmanager
import hashlib
import importlib.metadata
import json
import os
from pathlib import Path
import platform
import shutil
import struct
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[3]
REGISTRY = ROOT / "docs/benchmarks/creature-factory-next/baselines.json"
WORKER = Path(__file__).with_name("blender_audit.py")


class AuditError(ValueError):
    """Invalid or changed evidence, never artistic rejection."""


def sha256(path: Path) -> str:
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def write_json(path: Path, value: dict) -> None:
    """Readers see the old complete report or the new complete report."""
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, name = tempfile.mkstemp(dir=path.parent, prefix=".audit-", suffix=".tmp")
    try:
        with os.fdopen(fd, "w") as stream:
            json.dump(value, stream, indent=2, allow_nan=False)
            stream.write("\n")
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(name, path)
    finally:
        Path(name).unlink(missing_ok=True)


def evidence_path(root: Path, value: str) -> Path:
    path = (root / value).resolve()
    if not path.is_relative_to(root.resolve()) or not path.is_file():
        raise AuditError(f"Invalid evidence path: {value}")
    return path


def verify_sources(root: Path, registry: dict) -> dict:
    files = list(registry["references"])
    for benchmark in registry["benchmarks"]:
        files.extend(benchmark["preserved_files"])
        source = evidence_path(root, benchmark["source"])
        if sha256(source) != benchmark["sha256"]:
            raise AuditError(f"Benchmark source changed: {benchmark['id']}")
    for item in files:
        path = evidence_path(root, item["path"])
        if path.stat().st_size != item["bytes"] or sha256(path) != item["sha256"]:
            raise AuditError(f"Preserved source changed: {item['path']}")
    return {"status": "verified", "files": len(files), "bytes": sum(x["bytes"] for x in files)}


def glb_metadata(path: Path) -> dict:
    """Count the actual exported glTF accessor data, not a historical report.

    Counts are per primitive (seam/material duplication included), not welded
    topology. Blender independently measures topology and transforms.
    """
    raw = path.read_bytes()
    if len(raw) < 20:
        raise AuditError("Truncated GLB")
    magic, version, length = struct.unpack_from("<III", raw)
    if magic != 0x46546C67 or version != 2 or length != len(raw):
        raise AuditError("Invalid GLB header or length")
    chunks, offset = [], 12
    while offset < len(raw):
        if offset + 8 > len(raw):
            raise AuditError("Truncated GLB chunk header")
        size, kind = struct.unpack_from("<II", raw, offset)
        offset += 8
        if size % 4 or offset + size > len(raw):
            raise AuditError("Invalid GLB chunk size")
        chunks.append((kind, raw[offset:offset + size]))
        offset += size
    if not chunks or chunks[0][0] != 0x4E4F534A:
        raise AuditError("GLB must start with JSON")
    try:
        doc = json.loads(chunks[0][1])
        primitives = [p for m in doc.get("meshes", []) for p in m["primitives"]]
        result = []
        for mesh in doc.get("meshes", []):
            triangles = vertices = 0
            for p in mesh["primitives"]:
                if p.get("mode", 4) != 4:
                    raise AuditError("Baseline requires TRIANGLES; no silent conversion")
                count = doc["accessors"][p["attributes"]["POSITION"]]["count"]
                indices = doc["accessors"][p["indices"]]["count"] if "indices" in p else count
                if count < 0 or indices < 0 or indices % 3:
                    raise AuditError("Invalid triangle accessor count")
                vertices += count
                triangles += indices // 3
            result.append({"name": mesh.get("name"), "triangles": triangles,
                           "exported_vertices": vertices,
                           "over_roblox_individual_mesh_limit": triangles > 20000})
    except (KeyError, IndexError, TypeError, json.JSONDecodeError) as exc:
        raise AuditError(f"Invalid glTF metadata: {exc}") from exc
    return {"triangles": sum(m["triangles"] for m in result),
            "exported_vertices": sum(m["exported_vertices"] for m in result),
            "meshes": result, "skins": len(doc.get("skins", [])),
            "joint_count_per_skin": [len(s["joints"]) for s in doc.get("skins", [])],
            "materials": len(doc.get("materials", [])),
            "images": len(doc.get("images", [])),
            "animations": len(doc.get("animations", [])),
            "primitive_attribute_sets": [sorted(p["attributes"]) for p in primitives],
            "scope": "exported accessors; per-primitive vertices may duplicate seams"}


def resource_limits(cgroup: Path = Path("/sys/fs/cgroup")) -> dict:
    def read(name):
        try:
            return (cgroup / name).read_text().strip()
        except OSError:
            return None
    memory, quota = read("memory.max"), read("cpu.max")
    parts = quota.split() if quota else []
    return {"cpu_count_visible": os.cpu_count(),
            "cpu_quota": int(parts[0]) / int(parts[1]) if parts and parts[0] != "max" else None,
            "memory_limit_bytes": int(memory) if memory and memory != "max" else None,
            "disk_free_bytes": shutil.disk_usage(ROOT).free,
            "nvidia_smi": shutil.which("nvidia-smi"),
            "gpu_device_paths": sorted(str(p) for p in Path("/dev").glob("nvidia*")),
            "gpu_scope": "NVIDIA executable/device discovery only; CPU renderer explicitly selected; other accelerators not validated"}


def sampled_rss(pid: int) -> int:
    """Linux root process RSS. Some managed hosts omit /proc children files."""
    try:
        text = Path(f"/proc/{pid}/status").read_text()
        rss = next(int(line.split()[1]) * 1024 for line in text.splitlines() if line.startswith("VmRSS:"))
        return rss
    except (OSError, StopIteration, ValueError):
        return 0


def measured_command(command: list[str], log: Path, timeout: float) -> dict:
    start, peak = time.monotonic(), 0
    with log.open("w") as stream:
        process = subprocess.Popen(command, stdout=stream, stderr=subprocess.STDOUT,
                                   env={**os.environ, "OMP_NUM_THREADS": "2", "OPENBLAS_NUM_THREADS": "2",
                                        "LIBGL_ALWAYS_SOFTWARE": "1"}, start_new_session=True)
        timed_out = False
        try:
            while process.poll() is None:
                peak = max(peak, sampled_rss(process.pid))
                if time.monotonic() - start > timeout:
                    import signal
                    os.killpg(process.pid, signal.SIGKILL)
                    timed_out = True
                    break
                try:
                    process.wait(timeout=0.1)
                except subprocess.TimeoutExpired:
                    pass
        finally:
            process.wait()
    return {"status": "timeout" if timed_out else "passed" if process.returncode == 0 else "failed",
            "returncode": process.returncode, "wall_seconds": round(time.monotonic() - start, 4),
            "sampled_peak_process_rss_bytes": peak,
            "rss_method": "Root process Linux /proc RSS sampled at 100ms; excludes descendants; lower bound on transient peaks. Blender also records its getrusage peak.",
            "log": log.name}


BLENDER_PROBE = '''import bpy, importlib.util, json, sys, numpy
from pathlib import Path
target = Path(sys.argv[sys.argv.index("--")+1])
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.mesh.primitive_monkey_add()
bpy.ops.export_scene.gltf(filepath=str(target), export_format="GLB", export_animations=False)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(target))
bpy.context.scene.render.engine = "CYCLES"
try:
    import xatlas
    atlas = {"available":True}
except Exception as exc:
    atlas = {"available":False, "error_type":type(exc).__name__, "error":str(exc)}
print("CF_PREFLIGHT " + json.dumps({"blender":bpy.app.version_string, "python":sys.version, "numpy":numpy.__version__, "xatlas_import":atlas, "glb_export_reimport_meshes":sum(o.type=="MESH" for o in bpy.context.scene.objects), "cycles_available":bpy.context.scene.render.engine == "CYCLES"}))
'''


def preflight(out: Path, blender: str = "blender") -> dict:
    packages = {}
    for name in ("numpy", "Pillow", "scipy", "torch", "torchvision", "xatlas", "trimesh", "open3d", "meshoptimizer"):
        try:
            packages[name] = importlib.metadata.version(name)
        except importlib.metadata.PackageNotFoundError:
            packages[name] = None
    result = {"platform": platform.platform(), "python": sys.version,
              "packages": packages, "resources": resource_limits(),
              "network_operations": [], "paid_services": False}
    executable = shutil.which(blender)
    if not executable:
        result["blender"] = {"status": "blocked", "reason": "blender executable missing"}
        return result
    log = out / "preflight-blender.log"
    probe = measured_command([executable, "--background", "--factory-startup", "--python-exit-code", "1",
                              "--python-expr", BLENDER_PROBE, "--", str(out / "preflight.glb")], log, 90)
    lines = log.read_text(errors="replace").splitlines()
    data = next((json.loads(line.removeprefix("CF_PREFLIGHT ")) for line in lines if line.startswith("CF_PREFLIGHT ")), None)
    probe["data"] = data
    if data is None or data.get("glb_export_reimport_meshes") != 1:
        probe["status"] = "failed"
    result["blender"] = probe
    return result


@contextmanager
def output_lock(out: Path):
    out.mkdir(parents=True, exist_ok=True)
    path = out / ".audit.lock"
    try:
        fd = os.open(path, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
    except FileExistsError as exc:
        raise AuditError("Audit output is locked; inspect prior process before recovering") from exc
    try:
        os.write(fd, str(os.getpid()).encode())
        os.close(fd)
        yield
    finally:
        path.unlink(missing_ok=True)


def validate_output(out: Path, *, allow_benchmark_docs=False) -> Path:
    out = out.resolve()
    for protected in ("asset-library", "games", "packages", "tools", "docs", ".github", ".git"):
        path = (ROOT / protected).resolve()
        if protected == "docs" and allow_benchmark_docs and out.is_relative_to(ROOT / "docs/benchmarks/creature-factory-next"):
            continue
        if out.is_relative_to(path) or path.is_relative_to(out):
            raise AuditError("Output must be separate from source trees")
    return out


def valid_cache(target: Path, key: str | None = None) -> dict | None:
    """Reject tampered, incomplete or escaping cache entries before using images."""
    try:
        stamp = json.loads((target / "complete.json").read_text())
        if key is not None and stamp.get("key") != key:
            return None
        outputs = stamp.get("outputs", {})
        if "metrics.json" not in outputs:
            return None
        for name, digest in outputs.items():
            path = evidence_path(target, name)
            if sha256(path) != digest:
                return None
        return stamp
    except (OSError, AuditError, ValueError, TypeError):
        return None


def audit(out: Path, *, render=False, resolution=256, timeout=600, blender="blender", resume=False) -> dict:
    out = validate_output(out)
    registry = json.loads(REGISTRY.read_text())
    verify_sources(ROOT, registry)
    runner_hash, worker_hash = sha256(Path(__file__)), sha256(WORKER) if render else None
    with output_lock(out):
        if (out / "audit.json").exists() and not resume:
            raise AuditError("Existing audit: use --resume or a new output directory")
        if (out / "audit.json").exists():
            history = out / "history"
            history.mkdir(exist_ok=True)
            shutil.copyfile(out / "audit.json", history / f"audit-{time.time_ns()}.json")
        report = {"schema": 1, "checkpoint": "C0", "reference_commit": registry["reference_commit"],
                  "registry_sha256": sha256(REGISTRY), "artistic_approval": False,
                  "publication_allowed": False, "measurements": {},
                  "limits": ["C0 audits existing assets; no reconstruction or optimization quality claim.",
                             "Reference illustrations have no measured depth/normal ground truth.",
                             "Synthetic fixtures and unseen holdout remain later checkpoint requirements."]}
        attempts = out / "attempts"
        attempts.mkdir(exist_ok=True)
        preflight_out = Path(tempfile.mkdtemp(dir=attempts, prefix="preflight-"))
        report["preflight"] = preflight(preflight_out, blender)
        report["preflight"]["output_directory"] = str(preflight_out.relative_to(out))
        write_json(out / "audit.json", report)
        for item in registry["benchmarks"]:
            source = evidence_path(ROOT, item["source"])
            entry = {"source": item["source"], "sha256": sha256(source),
                     "exported": glb_metadata(source), "historical_report": item["historical_report"]}
            if render and report["preflight"]["blender"]["status"] == "passed":
                target = out / item["id"]
                target.mkdir(exist_ok=True)
                key = hashlib.sha256(json.dumps({"source":entry["sha256"], "worker":worker_hash, "runner":runner_hash,
                    "blender":report["preflight"]["blender"]["data"], "resolution":resolution}, sort_keys=True).encode()).hexdigest()
                stamp, metrics = target / "complete.json", target / "metrics.json"
                cached = valid_cache(target, key) if resume else None
                if cached:
                    entry["execution"] = {"status":"cached", "original":cached["execution"]}
                else:
                    attempt_root = Path(tempfile.mkdtemp(dir=attempts, prefix=f"{item['id']}-"))
                    attempt = attempt_root / "outputs"
                    entry["execution"] = measured_command([shutil.which(blender), "--background", "--factory-startup", "--threads", "2",
                        "--python-exit-code", "1", "--python", str(WORKER), "--", "--source", str(source), "--out", str(attempt),
                        "--resolution", str(resolution)], attempt_root / "blender.log", timeout)
                    entry["execution"]["log"] = str((attempt_root / "blender.log").relative_to(out))
                    if sha256(Path(__file__)) != runner_hash or sha256(WORKER) != worker_hash:
                        raise AuditError("Audit code changed during execution; attempt retained, rerun from a fixed revision")
                    attempted_metrics = attempt / "metrics.json"
                    completed = json.loads(attempted_metrics.read_text()) if attempted_metrics.is_file() else {}
                    if (entry["execution"]["status"] == "passed" and completed.get("sourceUnchanged") is True
                            and completed.get("sourceSha256") == entry["sha256"]
                            and completed.get("status") == "measured_review_required"
                            and completed.get("totals", {}).get("triangles") == entry["exported"]["triangles"]):
                        if any(target.iterdir()):
                            preserved = Path(tempfile.mkdtemp(dir=out, prefix=f".{item['id']}-preserved-"))
                            preserved.rmdir()
                            target.rename(preserved)
                        else:
                            target.rmdir()
                        attempt.rename(target)
                        outputs = {p.name:sha256(p) for p in sorted(target.iterdir()) if p.is_file() and p != stamp}
                        write_json(stamp, {"key":key,"execution":entry["execution"], "outputs":outputs})
                    else:
                        entry["execution"]["status"] = "failed" if entry["execution"]["status"] == "passed" else entry["execution"]["status"]
                        entry["execution"]["preserved_failed_attempt"] = str(attempt_root.relative_to(out))
                if entry["execution"]["status"] in {"passed","cached"}:
                    entry["blender_measurements"] = json.loads(metrics.read_text())
            else:
                entry["execution"] = {"status":"not_requested" if not render else "blocked"}
            report["measurements"][item["id"]] = entry
            write_json(out / "audit.json", report)
            print(item["id"], entry["execution"]["status"], flush=True)
        report["preservation"] = verify_sources(ROOT, registry)
        report["status"] = "measured" if render and all(x["execution"]["status"] in {"passed","cached"} for x in report["measurements"].values()) else "inventory_only" if not render else "blocked"
        write_json(out / "audit.json", report)
        return report


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["audit", "preflight"])
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--render", action="store_true")
    parser.add_argument("--resume", action="store_true")
    parser.add_argument("--resolution", type=int, default=256)
    parser.add_argument("--timeout", type=float, default=600)
    parser.add_argument("--blender", default="blender")
    args = parser.parse_args(argv)
    if not 64 <= args.resolution <= 1024 or not 0 < args.timeout <= 3600:
        parser.error("Resolution must be 64..1024 and timeout 0..3600s (execution guardrails, not mesh caps)")
    try:
        args.out = validate_output(args.out)
        if args.command == "preflight":
            with output_lock(args.out.resolve()):
                result = preflight(args.out.resolve(), args.blender)
                write_json(args.out.resolve() / "preflight.json", result)
            print(json.dumps(result, indent=2))
            return int(result["blender"]["status"] != "passed")
        report = audit(args.out, render=args.render, resolution=args.resolution, timeout=args.timeout,
                       blender=args.blender, resume=args.resume)
        return int(report["status"] == "blocked")
    except (AuditError, OSError, ValueError) as exc:
        print(f"AUDIT_BLOCKED: {exc}", file=sys.stderr)
        return 2
