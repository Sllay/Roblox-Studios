import sys,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path[:0]=[str(ROOT/"tools/assets"),str(ROOT/"tools")]
from pack_import import validate_evidence,validate_plan,equivalent,WorkspaceError

class PackImportTests(unittest.TestCase):
    def report(self):
        return {"audit":{"policyVersion":2,"parts":1,"instances":2,"surfaces":1,"dependencies":["rbxassetid://1"],"rows":[{"class":"SurfaceAppearance","path":[{"name":"Surface"}],"maps":{"ColorMapContent":"rbxassetid://1","NormalMapContent":""}}]},"dependencyFetch":{"verified":True,"meshes":{},"textures":{"rbxassetid://1":"Success"}},"offlinePbr":[{"name":"Surface","properties":{"ColorMapContent":{"Uri":"rbxassetid://1"},"NormalMapContent":"None","TexturePackContent":{"Uri":"rbxassetid://2"}}}]}
    def test_pbr_fields_match(self):
        validate_evidence(self.report())
    def test_reject_missing_or_changed_dependency(self):
        for field in ("ColorMapContent","NormalMapContent","TexturePackContent"):
            r=self.report();del r["offlinePbr"][0]["properties"][field]
            with self.assertRaises(WorkspaceError):validate_evidence(r)
        r=self.report();r["offlinePbr"][0]["properties"]["ColorMapContent"]={"Uri":"rbxassetid://3"}
        with self.assertRaises(WorkspaceError):validate_evidence(r)
    def test_production_rejected(self):
        with self.assertRaises(WorkspaceError):validate_plan({"environment":"production"},{})
    def test_geometry_precision(self):
        self.assertTrue(equivalent({"position":[1,2.0001,3]},{"position":[1.0,2,3]}))
        self.assertFalse(equivalent({"mesh":"rbxassetid://1"},{"mesh":"rbxassetid://2"}))
