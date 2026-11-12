import sys,unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/"tools"))
from sharded_scene_sync import merge_service,identity_digest,PAGE
from workspace import WorkspaceError
class ShardTests(unittest.TestCase):
    def test_complete_and_reject_missing(self):
        rows=[{"service":"Workspace","path":[{"name":f"p{i:04d}","class":"Part","ordinal":1}]} for i in range(PAGE+1)]
        def p(first,last):
            return {"service":"Workspace","loadedVersion":16,"total":len(rows),"identityDigest":identity_digest(rows),"noPlaceWrites":True,"first":first,"last":last,"objects":rows[first-1:last]}
        pages=[p(1,PAGE),p(PAGE+1,PAGE+1)]
        self.assertEqual(merge_service("Workspace",pages,16),rows)
        for bad in ([pages[0]],[pages[0],{**pages[1],"loadedVersion":17}],[pages[0],{**pages[1],"identityDigest":"bad"}],[pages[0],{**pages[1],"first":PAGE}]):
            with self.assertRaises(WorkspaceError):merge_service("Workspace",bad,16)
    def test_empty(self):
        p={"service":"Lighting","loadedVersion":16,"total":0,"identityDigest":identity_digest([]),"noPlaceWrites":True,"first":1,"last":0,"objects":[]}
        self.assertEqual(merge_service("Lighting",[p],16),[])
