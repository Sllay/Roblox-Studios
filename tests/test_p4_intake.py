import sys
import tempfile
import unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/"tools/assets"))
from intake import load_intake, run_batch
from pipeline import WorkspaceError

class P4IntakeTests(unittest.TestCase):
    def test_manifest(self):
        rows=load_intake(ROOT/"games/maps/mapa-principal/game/assets/intake-p4.json")
        self.assertEqual(len(rows),12)
        self.assertEqual(len({r["id"] for r in rows}),12)
        self.assertTrue(all(r["importStatus"]=="not_imported" for r in rows))
    def test_rate_limit_stops(self):
        calls=[]
        def fake(target,key,asset_id):
            calls.append(asset_id)
            raise WorkspaceError("HTTP 429")
        with tempfile.TemporaryDirectory() as d:
            result=run_batch({}, "test", [{"id":"1"},{"id":"2"}], Path(d),fake)
            self.assertEqual(calls,["1"])
            self.assertEqual(result[0]["status"],"rate_limited")
            self.assertFalse(result[0]["importAuthorized"])

    def test_mixed_inventory_never_authorizes_import(self):
        def fake(target,key,asset_id):
            return {"pack":{"inventoryTruncated":False,"totalModels":0,"scriptsInPack":1,
                "componentInventory":{"codeExecuted":False,"truncated":False,"total":3,
                    "classes":{"ParticleEmitter":2,"Script":1},"rows":[]}}}
        with tempfile.TemporaryDirectory() as d:
            result=run_batch({}, "test", [{"id":"1"}], Path(d),fake)
            self.assertEqual(result[0]["status"],"inventory_observed")
            self.assertEqual(result[0]["scripts"],1)
            self.assertEqual(result[0]["components"],3)
            self.assertFalse(result[0]["importAuthorized"])
