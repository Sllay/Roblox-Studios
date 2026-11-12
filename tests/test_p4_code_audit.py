import sys
import unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/"tools/assets"))
from code_audit import summarize

class CodeAuditTests(unittest.TestCase):
    def test_require_and_tokens(self):
        report=summarize('-- require(999)\nlocal x=require(script.Parent.Octree)\nlocal y=require(123)\nlocal z=game:GetService("RunService")\nz.Heartbeat:Connect(function() end)')
        self.assertEqual(report["requires"],[{"kind":"script_relative","path":"script.Parent.Octree"},{"kind":"numeric_asset","assetId":"123"}])
        self.assertEqual(report["services"],["RunService"])
        self.assertEqual(report["visualTokens"]["Heartbeat"],1)
    def test_strings_and_comments(self):
        report=summarize('local s="loadstring" -- FireServer\n--[[ require(321) ]]\nlocal f=loadstring("x")')
        self.assertEqual(report["riskTokens"],{"loadstring":1})
        self.assertEqual(report["requires"],[])
