import importlib.util
import sys
import unittest
from pathlib import Path
from unittest.mock import patch
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/"tools"))
sys.path.insert(0,str(ROOT/"tools/assets"))
from access import assess,classify_failure,WorkspaceError

class AssetAccessTests(unittest.TestCase):
    def setUp(self):
        self.t=dict(game="demo",place="main",environment="staging",universeId="1",placeId="2")
    def test_denied_is_not_security_rejection(self):
        with patch("access.call",side_effect=WorkspaceError("Cloud task failed: Asset load denied or unavailable: User is not authorized to access Asset.")):
            r=assess(self.t,"key","123")
        self.assertEqual(r["status"],"asset_access_denied")
        self.assertFalse(r["loadable"])
        self.assertIsNone(r["policyPassed"])
        self.assertFalse(r["importAuthorized"])
    def test_loadable_rejected_and_pass_never_authorize_import(self):
        for allowed in (True,False):
            with patch("access.call",return_value={"loadedVersion":2,"audit":{"policyVersion":1,"allowed":allowed}}):
                r=assess(self.t,"key","123")
            self.assertTrue(r["loadable"])
            self.assertIs(r["policyPassed"],allowed)
            self.assertFalse(r["importAuthorized"])
    def test_cloud_and_rate_errors_distinct(self):
        for message,status in [("Roblox API HTTP 429","rate_limited"),("Roblox API HTTP 403","cloud_access_denied"),("unexpected","unknown_error"),("Asset load denied or unavailable: server unavailable","asset_unavailable")]:
            self.assertEqual(classify_failure(WorkspaceError(message))[0],status)

    def test_restricted_texture_is_incomplete_not_access_denied(self):
        with patch("access.call",return_value={"loadedVersion":1,"audit":{"policyVersion":1,"allowed":False,"inspectionComplete":False}}):
            r=assess(self.t,"key","123")
        self.assertEqual(r["status"],"loadable_audit_incomplete")
        self.assertTrue(r["loadable"])
        self.assertFalse(r["importAuthorized"])
