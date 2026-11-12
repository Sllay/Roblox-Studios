import sys,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/"tools"))
from place_provision import check_mapping,WorkspaceError
class ProvisionTests(unittest.TestCase):
    def test_alias_rejected(self):
        t={"g":{"environments":{"staging":{"universeId":"1","placeIds":{"main":"2"}},"production":{"universeId":"3","placeIds":{"main":"4"}}}}}
        g={"g":{}}
        check_mapping(g,t,"g","main","1","2")
        for game,place,u,p in [("x","main","3","5"),("x","main","1","2"),("g","main","1","8"),("x","other","8","9")]:
            with self.assertRaises(WorkspaceError):check_mapping(g,t,game,place,u,p)
