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

    def test_duplicate_names_require_exact_hierarchy(self):
        from copy import deepcopy
        r=self.report();a=r["audit"]["rows"][0];o=r["offlinePbr"][0]
        a["path"]=[{"name":"Trunk","class":"MeshPart","index":1},{"name":"Surface","class":"SurfaceAppearance","index":1}]
        o["path"]=deepcopy(a["path"])
        b=deepcopy(a);b["path"][0]={"name":"Leaves","class":"MeshPart","index":2}
        q=deepcopy(o);q["path"]=deepcopy(b["path"])
        r["audit"]["rows"].append(b);r["audit"]["surfaces"]=2;r["offlinePbr"].append(q)
        validate_evidence(r)
        q["path"]=deepcopy(o["path"])
        with self.assertRaises(WorkspaceError):validate_evidence(r)
    def test_legacy_comparison(self):
        from pack_import import offline_pbr_equal
        from copy import deepcopy
        old=self.report()["offlinePbr"];new=deepcopy(old);new[0]["path"]=[{"name":"Surface","class":"SurfaceAppearance","index":1}]
        self.assertTrue(offline_pbr_equal(old,new))
        self.assertFalse(offline_pbr_equal(old+old,new+new))
