"""Regression gates for the native V39 rabbit posture/locomotion split.

Tests use FK of the 19 actual Roblox bones, and do not upload or publish.
"""
from __future__ import annotations

import json
import math
import subprocess
import sys
import tempfile
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "asset-library/candidates/rabbit-v3-cartoon-v2-mobile-lod0/asset.glb"
AUTHOR = ROOT / "tools/creature_factory/rabbit_animation_author_v39.py"


def distance(a, b):
    return math.dist(a, b)


class RabbitV39(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.work = tempfile.TemporaryDirectory()
        subprocess.run([sys.executable, str(AUTHOR), str(SOURCE),
                        cls.work.name], cwd=ROOT, check=True, timeout=180)
        cls.manifest = json.loads(
            (Path(cls.work.name) / "manifest.json").read_text())

    @classmethod
    def tearDownClass(cls):
        cls.work.cleanup()

    def clip(self, name):
        return self.manifest["clips"][name]["samples"]

    def test_no_publication_and_only_four_original_clips(self):
        self.assertEqual(self.manifest["stage"], "v39_preview_only_not_uploaded")
        self.assertEqual(self.manifest["rig_bones"], 19)
        self.assertEqual(set(self.manifest["clips"]),
                         {"Idle", "Walk", "Run", "ScratchEar"})

    def test_idle_stands_upright_and_does_not_fold_torso(self):
        frames = self.clip("Idle")
        self.assertTrue(all(r["head"][1] > 1.60 for r in frames))
        self.assertTrue(all(r["forepaw"][1] > .7 for r in frames))
        self.assertLess(max(distance(r["head"], frames[0]["head"])
                            for r in frames), .08)
        self.assertTrue(all(abs(r["root_y"]) < .0001 for r in frames))

    def test_walk_is_upright_with_hind_only_hop(self):
        frames = self.clip("Walk")
        heights = [r["root_y"] for r in frames]
        self.assertGreater(max(heights)-min(heights), .47)
        self.assertTrue(all(r["head"][1] > 1.5 for r in frames))
        self.assertTrue(all(r["forepaw"][1] >
                            r["hindpaw"][1]+.4 for r in frames))
        self.assertGreater(max(r["hindpaw"][1] for r in frames)-
                           min(r["hindpaw"][1] for r in frames), .3)
        self.assertLess(max(distance(r["forepaw"], frames[0]["forepaw"])
                            for r in frames), .8)
        self.assertLess(distance(frames[0]["head"],frames[-1]["head"]), .005)

    def test_only_run_uses_quadruped_posture(self):
        running = self.clip("Run")
        self.assertLess(min(r["head"][1] for r in running), 1.4)
        self.assertLess(min(r["forepaw"][1] for r in running), .6)
        self.assertGreater(max(r["root_y"] for r in running), 1.0)
        self.assertGreater(min(r["head"][1] for r in self.clip("Idle")),
                           min(r["head"][1] for r in running)+.4)

    def test_groom_front_right_paw_only_while_upright(self):
        rows = self.clip("ScratchEar")
        self.assertFalse(self.manifest["clips"]["ScratchEar"]["loop"])
        start = rows[0]
        self.assertTrue(all(r["head"][1] > 1.6 for r in rows))
        self.assertTrue(all(abs(r["root_y"]) < .0001 for r in rows))
        self.assertGreater(max(r["forepaw_right"][1] for r in rows)-
                           start["forepaw_right"][1], .65)
        for key in ("hindpaw", "hindpaw_right", "forepaw", "head"):
            self.assertLess(max(distance(r[key],start[key]) for r in rows),
                            .025, key)
        # The ear itself tilts forward (-Z) and lowers (-Y), rather than
        # standing rigid while the hand oscillates somewhere nearby.
        self.assertLess(min(r["ear_tip_right"][2] for r in rows),
                        start["ear_tip_right"][2]-.14)
        self.assertLess(min(r["ear_tip_right"][1] for r in rows),
                        start["ear_tip_right"][1]-.14)

    def test_xml_bone_hierarchy_and_seamless_loop(self):
        for name, clip in self.manifest["clips"].items():
            xml = ET.parse(Path(self.work.name) / clip["file"]).getroot()
            frames = xml.findall('.//Item[@class="Keyframe"]')
            self.assertEqual(len(frames),clip["frames"],name)
            self.assertTrue(all(len(f.findall('.//Item[@class="Pose"]'))==20
                                for f in frames),name)
            if clip["loop"]:
                a, b = clip["samples"][0], clip["samples"][-1]
                for bone in ("head","forepaw","hindpaw"):
                    self.assertLess(distance(a[bone],b[bone]), .005,
                                    (name,bone))


if __name__ == "__main__":
    unittest.main()
