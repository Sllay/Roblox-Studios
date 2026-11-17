"""C0 evidence integrity and failure handling, no inference or source writes."""
import json
import os
from pathlib import Path
import struct
import sys
import tempfile
import unittest

from tools.creature_factory.next import audit as cf


class AuditTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)

    def glb(self, doc):
        raw = json.dumps(doc).encode()
        raw += b" " * (-len(raw) % 4)
        p = self.root / "fixture.glb"
        p.write_bytes(struct.pack("<III", 0x46546C67, 2, len(raw) + 20)
                      + struct.pack("<II", len(raw), 0x4E4F534A) + raw)
        return p

    def test_actual_exported_baseline_counts(self):
        registry = json.loads(cf.REGISTRY.read_text())
        expected = [(6136, 0), (26224, 0), (51732, 0), (60968, 19), (3120, 14)]
        for item, (triangles, bones) in zip(registry["benchmarks"], expected):
            with self.subTest(asset=item["id"]):
                d = cf.glb_metadata(cf.ROOT / item["source"])
                self.assertEqual(d["triangles"], triangles)
                self.assertEqual(sum(d["joint_count_per_skin"]), bones)
        final = cf.glb_metadata(cf.ROOT / registry["benchmarks"][3]["source"])
        self.assertEqual(final["exported_vertices"], 37832)
        self.assertTrue(any(m["over_roblox_individual_mesh_limit"] for m in final["meshes"]))

    def test_source_registry_has_no_asset_promotion(self):
        registry = json.loads(cf.REGISTRY.read_text())
        self.assertFalse(registry["artistic_approval"])
        self.assertFalse(registry["publication_allowed"])
        self.assertEqual(cf.verify_sources(cf.ROOT, registry)["status"], "verified")

    def test_reject_truncated_and_false_length(self):
        for raw in (b"glTF", struct.pack("<III", 0x46546C67, 2, 999) + b" " * 12):
            p = self.root / "bad.glb"
            p.write_bytes(raw)
            with self.assertRaises(cf.AuditError):
                cf.glb_metadata(p)

    def test_reject_nontriangles_instead_of_miscounting(self):
        p = self.glb({"meshes":[{"primitives":[{"mode":5}]}]})
        with self.assertRaisesRegex(cf.AuditError, "TRIANGLES"):
            cf.glb_metadata(p)

    def test_reject_fractional_triangle(self):
        p = self.glb({"accessors":[{"count":4}], "meshes":[{"primitives":[{"attributes":{"POSITION":0}}]}]})
        with self.assertRaises(cf.AuditError):
            cf.glb_metadata(p)

    def test_reject_chunk_past_file_end(self):
        p = self.glb({})
        data = bytearray(p.read_bytes())
        struct.pack_into("<I", data, 12, 200)
        p.write_bytes(data)
        with self.assertRaises(cf.AuditError):
            cf.glb_metadata(p)

    def test_reference_changed_fails_closed(self):
        p = self.root / "source.png"
        p.write_bytes(b"original bytes")
        item = {"path":p.name,"sha256":cf.sha256(p),"bytes":p.stat().st_size}
        registry = {"references":[item],"benchmarks":[]}
        self.assertEqual(cf.verify_sources(self.root, registry)["files"], 1)
        p.write_bytes(b"modified bytes")
        with self.assertRaisesRegex(cf.AuditError, "changed"):
            cf.verify_sources(self.root, registry)

    def test_path_traversal_and_symlink_rejected(self):
        with self.assertRaises(cf.AuditError):
            cf.evidence_path(self.root, "../source.png")
        (self.root / "escape").symlink_to(cf.REGISTRY)
        with self.assertRaises(cf.AuditError):
            cf.evidence_path(self.root, "escape")

    def test_concurrent_writers_rejected_and_lock_released(self):
        with cf.output_lock(self.root):
            with self.assertRaisesRegex(cf.AuditError, "locked"):
                with cf.output_lock(self.root):
                    self.fail("Second writer entered")
        with cf.output_lock(self.root):
            pass
        self.assertFalse((self.root / ".audit.lock").exists())

    def test_atomic_report_retained_when_nan_rejected(self):
        path = self.root / "report.json"
        cf.write_json(path, {"state":"measured"})
        with self.assertRaises(ValueError):
            cf.write_json(path, {"metric":float("nan")})
        self.assertEqual(json.loads(path.read_text()), {"state":"measured"})
        self.assertEqual(list(self.root.glob(".audit-*.tmp")), [])

    def test_real_subprocess_failure_recorded(self):
        log = self.root / "failed.log"
        result = cf.measured_command([sys.executable, "-c", "print('probe'); raise SystemExit(7)"], log, 3)
        self.assertEqual(result["status"], "failed")
        self.assertEqual(result["returncode"], 7)
        self.assertIn("probe", log.read_text())

    def test_rss_measures_without_proc_children_extension(self):
        if not Path("/proc/self/status").exists():
            self.skipTest("Linux process RSS probe")
        self.assertGreater(cf.sampled_rss(os.getpid()), 0)

    def test_timeout_kills_job_and_preserves_log(self):
        log = self.root / "timeout.log"
        result = cf.measured_command([sys.executable, "-c", "import time; print('started',flush=True); time.sleep(10)"], log, .15)
        self.assertEqual(result["status"], "timeout")
        self.assertLess(result["wall_seconds"], 3)
        self.assertIn("started", log.read_text())

    def test_cgroup_effective_limits(self):
        (self.root / "memory.max").write_text(str(8 * 1024**3))
        (self.root / "cpu.max").write_text("200000 100000")
        limits = cf.resource_limits(self.root)
        self.assertEqual(limits["memory_limit_bytes"], 8 * 1024**3)
        self.assertEqual(limits["cpu_quota"], 2)

    def test_audit_cannot_write_inside_assets(self):
        with self.assertRaises(cf.AuditError):
            cf.audit(cf.ROOT / "asset-library/candidates/new-audit")

    def test_cached_images_are_verified_and_tampering_invalidates(self):
        metrics = self.root / "metrics.json"
        image = self.root / "clay.png"
        metrics.write_text('{"status":"measured_review_required"}')
        image.write_bytes(b"immutable image bytes")
        cf.write_json(self.root / "complete.json", {"key":"v1", "outputs":{
            "metrics.json":cf.sha256(metrics), "clay.png":cf.sha256(image)}})
        self.assertIsNotNone(cf.valid_cache(self.root, "v1"))
        self.assertIsNone(cf.valid_cache(self.root, "v2"))
        image.write_bytes(b"corrupted image")
        self.assertIsNone(cf.valid_cache(self.root, "v1"))

    def test_empty_or_traversing_cache_not_accepted(self):
        cf.write_json(self.root / "complete.json", {"key":"v1","outputs":{}})
        self.assertIsNone(cf.valid_cache(self.root, "v1"))
        cf.write_json(self.root / "complete.json", {"key":"v1","outputs":{"metrics.json":"bad","../outside":"bad"}})
        self.assertIsNone(cf.valid_cache(self.root, "v1"))

    def test_comparison_output_cannot_mutate_asset_library(self):
        with self.assertRaises(cf.AuditError):
            cf.validate_output(cf.ROOT / "asset-library/new-comparison", allow_benchmark_docs=True)


if __name__ == "__main__":
    unittest.main()
