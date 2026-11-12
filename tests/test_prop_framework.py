import sys,unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/"tools"))
from prop_framework import plan,resolve

class Flat:
    tiles={"a":[0,0,0,80,20,80],"b":[80,0,0,160,20,80]}
    cells={(i,j):(0,"Grass",False) for i in range(40) for j in range(20)}
    tile_of={k:("a" if k[0]<20 else "b") for k in cells}
    def cell_key(self,x,z):return int(x//4),int(z//4)
    def evaluate(self,x,z,r,occ):
        if occ.blocked(x,z,r["radius"]+r["spacing"]):return "occupied",None
        return None,{"height":0,"normal":[.2,.979795897,0]}

class FrameworkTests(unittest.TestCase):
    def test_scatter(self):
        specs=[{"id":"Branch","template":"ResourceProp","count":30,"radius":1},{"id":"Stone","template":"ResourceProp","count":30,"radius":1}]
        a=plan(Flat(),[],specs,123)
        self.assertEqual(a,plan(Flat(),[],list(reversed(specs)),123))
        self.assertTrue(a["complete"])
        self.assertEqual(len(a["rows"]),60)
        self.assertEqual(len({r["id"] for r in a["rows"]}),60)
        for i,r in enumerate(a["rows"]):
            self.assertEqual(r["normal"],[.2,.979795897,0])
            self.assertTrue(0<=r["yaw"]<360)
            for s in a["rows"][:i]:
                self.assertGreaterEqual(((r["x"]-s["x"])**2+(r["z"]-s["z"])**2)**.5,r["radius"]+s["radius"]+4-1e-9)
    def test_upright(self):
        a=plan(Flat(),[],[{"id":"Tree","template":"VegetationProp","count":4,"radius":1}],1)
        self.assertTrue(a["complete"])
        self.assertTrue(all(r["normal"]==[0,1,0] for r in a["rows"]))
    def test_invalid(self):
        with self.assertRaises(ValueError):resolve({"template":"ResourceProp","count":-1,"radius":1})
    def test_capacity(self):
        a=plan(Flat(),[],[{"id":"Branch","template":"ResourceProp","count":10000,"radius":10}],1)
        self.assertFalse(a["complete"])
if __name__=="__main__":unittest.main()
