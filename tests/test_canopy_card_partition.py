import sys, unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/"tools"/"asset_factory"))
from canopy_card_partition import partition_cards

def cards(n):
    p=[];f=[]
    for i in range(n):
        j=len(p);x=float(i*3)
        p.extend([(x,0,0),(x+1,0,0),(x+1,1,0),(x,1,0)])
        f.extend([(j,j+1,j+2),(j,j+2,j+3)])
    return p,f

class CanopyPartitionTests(unittest.TestCase):
    def test_even_exact_balance_and_unchanged_faces(self):
        p,f=cards(10);before=(p[:],f[:]);r=partition_cards(p,f)
        self.assertEqual((r["lightCards"],r["darkCards"]),(5,5))
        self.assertEqual(sorted(r["light"]+r["dark"]),list(range(20)))
        self.assertEqual((p,f),before)
        self.assertEqual(r,partition_cards(p,f))
    def test_odd_balance(self):
        p,f=cards(5);r=partition_cards(p,f)
        self.assertEqual((r["lightCards"],r["darkCards"]),(3,2))
    def test_welded_fails(self):
        p,f=cards(2);f[2]=(0,5,6);f[3]=(0,6,7)
        with self.assertRaises(ValueError):partition_cards(p,f)
    def test_nonplanar_fails(self):
        p,f=cards(2);p[3]=(0,1,1)
        with self.assertRaises(ValueError):partition_cards(p,f)
    def test_one_card_fails(self):
        with self.assertRaises(ValueError):partition_cards(*cards(1))
    def test_invalid_index_fails(self):
        p,f=cards(2);f[0]=(0,1,999)
        with self.assertRaises(ValueError):partition_cards(p,f)
    def test_each_card_is_indivisible(self):
        p,f=cards(12);r=partition_cards(p,f)
        for i in range(0,len(f),2):
            self.assertEqual(i in r["light"],i+1 in r["light"])
