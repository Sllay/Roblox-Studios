"""Non-negotiable scope/evidence gate for the complete medieval solo game.

The design can change only by updating the canonical design and its coverage
matrix explicitly. Compiling gameplay files cannot certify a mechanic.
"""
from __future__ import annotations
import json
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DOCS = ROOT / "games/maps/entre-reinos/docs"
MATRIX = DOCS / "FEATURE_COMPLETENESS_AUDIT.md"
STATUS = DOCS / "RUNNER_STATUS.json"
ROW = re.compile(r"^\|\s*(ER-\d{3})\s*\|\s*([^|]+)\|\s*([^|]+)\|\s*([^|]+)\|\s*$",re.M)
STATES = {"PARCIAL","AUSENTE","PLANEJADO","VALIDADO"}

def owned_by(number: int) -> str:
    if number <= 4: return "T1-R1/F"
    if number <= 11: return "T1-R2/F"
    if number <= 20: return "T1-R3/F"
    if number <= 27: return "T2-R1"
    if number <= 35: return "T2-R2"
    if number <= 44: return "T2-R3"
    if number <= 48: return "T3-R1"
    if number <= 51: return "T3-R2"
    return "T3-R3"

def load_rows():
    text = MATRIX.read_text(encoding="utf-8")
    rows = [(key.strip(), owner.strip(), state.strip(), contract.strip())
            for key,owner,state,contract in ROW.findall(text)]
    return text, rows

class EntreReinosFeatureClosure(unittest.TestCase):
    def test_all_58_launcher_features_have_exactly_one_owner(self):
        _,rows=load_rows()
        self.assertEqual(len(rows),58,"Missing or duplicated launch requirements")
        self.assertEqual(len({r[0] for r in rows}),58)
        self.assertEqual({r[0] for r in rows},
                         {f"ER-{i:03}" for i in range(1,59)})
        for key,owner,state,contract in rows:
            number=int(key.split("-")[1])
            self.assertEqual(owner,owned_by(number),key)
            self.assertIn(state,STATES,key)
            self.assertGreater(len(contract),55,key)
            self.assertNotIn("TODO",contract.upper(),key)

    def test_no_partially_implemented_baseline_rewritten_as_done(self):
        _,rows=load_rows()
        by_id={r[0]:r for r in rows}
        # These have actual code but are specifically known to be incomplete:
        for key in ["ER-002","ER-007","ER-008","ER-009","ER-010",
                    "ER-014","ER-015","ER-017","ER-019"]:
            self.assertIn(by_id[key][2],STATES,key)
        # A future promotion to VALIDADO requires a signed external proof
        # record, not merely editing the state cell in this markdown.
        for key,owner,state,_contract in rows:
            if state!="VALIDADO": continue
            path=DOCS/"feature-evidence"/f"{key}.json"
            self.assertTrue(path.is_file(),f"{key}: missing evidence record")
            data=json.loads(path.read_text(encoding="utf-8"))
            for field in ("commit","ciRun","engineRun","mobileEvidence",
                          "saveLoadEvidence","abuseTest","creatorApproval"):
                self.assertIsInstance(data.get(field),str,
                                      f"{key}: missing {field}")
                self.assertTrue(data[field].strip(),f"{key}: empty {field}")
            self.assertEqual(data.get("requirementId"),key)
            self.assertEqual(data.get("decision"),"approved")

    def test_future_release_requires_cumulative_no_open_requirements(self):
        _,rows=load_rows()
        seasons=json.loads(STATUS.read_text(encoding="utf-8"))["seasons"]
        for season in seasons:
            if season["status"] not in ("validated","user_approved","released"):
                continue
            relevant=[r for r in rows
                      if r[1].startswith(season["id"])]
            open_items=[r[0] for r in relevant if r[2]!="VALIDADO"]
            self.assertFalse(open_items,
                f"{season['id']} may not be closed while open: {open_items}")
            prior=int(season["id"][1:])
            # T2/T3 may not be approved while T1/T2 criteria regress.
            old=[r[0] for r in rows if int(r[1][1])<prior and r[2]!="VALIDADO"]
            self.assertFalse(old,
                f"Previously approved systems regressed before {season['id']}: {old}")

    def test_no_private_lore_or_out_of_scope_multiplayer_in_launcher_matrix(self):
        text,_=load_rows()
        self.assertIn("fora da primeira versão solo",text)
        self.assertIn("PvP",text)
        self.assertIn("camada F1/F2/F3",text)
        self.assertIn("não é depósito",text)

if __name__=="__main__":
    unittest.main()
