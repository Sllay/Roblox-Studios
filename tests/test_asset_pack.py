import sys
import unittest
from pathlib import Path
from unittest.mock import patch
ROOT=Path(__file__).resolve().parents[1]
sys.path[:0]=[str(ROOT/"tools/assets"),str(ROOT/"tools")]
import pack
class PackTests(unittest.TestCase):
    def test_selector(self):
        valid=[{"index":1,"name":"Trees","class":"Folder"},{"index":2,"name":"Oak","class":"Model"}]
        self.assertEqual(pack.validate_selector(valid),valid)
        for invalid in ([],[{"index":0,"name":"Oak","class":"Model"}],[{"index":True,"name":"Oak","class":"Model"}]):
            with self.assertRaises(pack.WorkspaceError):pack.validate_selector(invalid)
    def test_read_only_extraction_contract(self):
        t={"universeId":"1","placeId":"2"}
        report={"pack":{"schemaVersion":1,"candidates":[],"extraction":{"detached":True,"importAuthorized":False}}}
        with patch.object(pack,"call",return_value=report) as remote:
            self.assertEqual(pack.inspect(t,"key","123",sample=True),report)
            remote.assert_called_once_with(t,"key","pack_inventory","123",sample=True)
    def test_unexpected_authorization_rejected(self):
        with patch.object(pack,"call",return_value={"pack":{"schemaVersion":1,"candidates":[],"extraction":{"detached":True,"importAuthorized":True}}}):
            with self.assertRaises(pack.WorkspaceError):pack.inspect({},"key","123")
