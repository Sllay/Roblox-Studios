import sys,unittest
from copy import deepcopy
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/"tools"))
from default_clone_delta import split_default_clones
from scene_sync import key_for,reconcile
def row(n):
    return {"service":"StarterPlayer","path":[{"class":"ModuleScript","name":"PlayerModule","ordinal":n}],"name":"PlayerModule","class":"ModuleScript","managedId":"","ambiguous":True,"childCount":0,"properties":{"sourceHash":"hash"}}
class DefaultCloneTests(unittest.TestCase):
    def test_exact_clone_only(self):
        base={"records":{key_for(r):r for r in [row(1),row(2)]}}
        after=deepcopy(base);r=row(3);after["records"][key_for(r)]=r
        changes=reconcile(base,after)["external"]
        self.assertEqual(len(split_default_clones(base,after,changes)[1]),1)
        r["properties"]["sourceHash"]="different"
        self.assertEqual(len(split_default_clones(base,after,changes)[1]),0)
