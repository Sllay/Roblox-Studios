import importlib.util
import sys
import unittest
from pathlib import Path
from unittest.mock import patch
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/"tools"))
spec=importlib.util.spec_from_file_location("asset_pipeline",ROOT/"tools/assets/pipeline.py")
pipeline=importlib.util.module_from_spec(spec)
spec.loader.exec_module(pipeline)

class AssetPipelineTests(unittest.TestCase):
    def setUp(self):
        self.target=dict(game="demo",place="main",environment="staging",universeId="1",placeId="2")
        self.report=dict(universeId="1",placeId="2",assetId="123",loadedVersion=5,
            audit=dict(policyVersion=1,allowed=True,issues=[],signature=["record"],parts=1))
        self.catalog={"assets":[{"id":"123","reviewStatus":"visual_shortlisted","biome":"praia"}]}
    def plan(self):
        return pipeline.prepare(self.target,"123","tree-one",[1,2,3],0,"praia","Reviewed Creator Store usage permission",self.report,self.catalog)
    def test_valid_plan(self):
        p=self.plan()
        self.assertEqual(p["expectedVersion"],5)
        self.assertEqual(p["managedId"],"tree-one")
        self.assertEqual(len(p["auditSha256"]),64)
    def test_reject_production(self):
        self.target["environment"]="production"
        with self.assertRaises(pipeline.WorkspaceError): self.plan()
    def test_reject_script_or_unknown_class(self):
        self.report["audit"]["allowed"]=False
        self.report["audit"]["issues"]=["Embedded code"]
        with self.assertRaises(pipeline.WorkspaceError): self.plan()
    def test_reject_wrong_biome_and_target(self):
        self.catalog["assets"][0]["biome"]="swamp"
        with self.assertRaises(pipeline.WorkspaceError): self.plan()
        self.catalog["assets"][0]["biome"]="praia"
        self.report["placeId"]="99"
        with self.assertRaises(pipeline.WorkspaceError): self.plan()
    def test_reaudit_before_parent_and_save(self):
        s=pipeline.build_source({"mode":"audit","assetId":"123","universeId":"1","placeId":"2"})
        self.assertNotIn("__RS_CONFIG__",s)
        self.assertLess(s.index('if cfg.mode == "audit"'),s.index("model.Parent=root"))
        self.assertLess(s.index("Asset changed since review"),s.index("model.Parent=root"))
        self.assertIn("game.PlaceVersion == cfg.expectedVersion",s)
        self.assertIn('not obj:IsA("LuaSourceContainer")',s)
    def test_invalid_asset_id(self):
        for val in ["0","123x","9007199254740992",None]:
            with self.assertRaises(pipeline.WorkspaceError): pipeline.check_id(val)
    def test_stale_plan_blocks_before_write(self):
        p=self.plan()
        import tempfile
        with tempfile.TemporaryDirectory() as tmp:
            with patch.object(pipeline,"capture",return_value={"loadedVersion":6,"objects":[]}):
                with patch.object(pipeline,"call") as remote:
                    with self.assertRaises(pipeline.WorkspaceError):
                        pipeline.apply(self.target,"secret",p,self.catalog,Path(tmp))
                    remote.assert_not_called()

    def test_apply_protocol_and_evidence(self):
        import tempfile
        import json
        p=self.plan()
        before=dict(schemaVersion=1,universeId="1",placeId="2",loadedVersion=5,objects=[],truncated=False)
        after=dict(before,loadedVersion=6,objects=[{"managedId":"tree-one","path":"Workspace.RSManagedAssets.tree-one"}])
        with tempfile.TemporaryDirectory() as tmp:
            output=Path(tmp)
            with patch.object(pipeline,"capture",side_effect=[before,after]), patch.object(pipeline,"call",side_effect=[
                    {"saved":True,"loadedVersion":5},
                    {"verified":True,"loadedVersion":6}]) as remote:
                pipeline.apply(self.target,"secret",p,self.catalog,output)
                self.assertEqual([x.args[2] for x in remote.call_args_list],["apply","verify"])
                self.assertEqual(remote.call_args_list[0].kwargs["signature"],["record"])
                self.assertEqual(remote.call_args_list[1].kwargs["position"],[1,2,3])
                self.assertEqual(json.loads((output/"diff.json").read_text())["afterVersion"],6)
                self.assertTrue((output/"verification.json").is_file())
