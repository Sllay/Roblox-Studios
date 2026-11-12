import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/"tools"))
import staging_readiness as readiness

class StagingReadinessTests(unittest.TestCase):
    def test_missing_mapping_stops_without_remote_access(self):
        with tempfile.TemporaryDirectory() as tmp:
            out=Path(tmp)/"report.json"
            with patch.object(readiness,"resolve",side_effect=readiness.WorkspaceError("Target is not configured")), patch.object(readiness,"run_task") as task:
                self.assertEqual(readiness.main(["--output",str(out)]),2)
                task.assert_not_called()
            report=json.loads(out.read_text())
            self.assertFalse(report["ready"])
            self.assertEqual(report["status"],"blocked")
    def test_read_only_remote_identity(self):
        with tempfile.TemporaryDirectory() as tmp:
            out=Path(tmp)/"report.json"
            target=dict(universeId="123",placeId="456")
            configs={"demo":{"environments":{"production":{"universeId":"987","placeIds":{"main":"654"}}}}}
            with patch.object(readiness,"load_all",return_value=({},configs)), patch.object(readiness,"resolve",return_value=target), patch.dict("os.environ",{"ROBLOX_OPEN_CLOUD_API_KEY":"test-key"}), patch.object(readiness,"run_task",return_value={"loadedVersion":3}) as task:
                self.assertEqual(readiness.main(["--output",str(out)]),0)
                task.assert_called_once()
            report=json.loads(out.read_text())
            self.assertTrue(report["ready"])
            self.assertEqual(report["loadedVersion"],3)
            self.assertIn("Read access only",report["note"])
    def test_production_alias_blocks(self):
        with tempfile.TemporaryDirectory() as tmp:
            out=Path(tmp)/"report.json"
            configs={"another":{"environments":{"production":{"universeId":"123","placeIds":{"main":"654"}}}}}
            with patch.object(readiness,"load_all",return_value=({},configs)), patch.object(readiness,"resolve",return_value={"universeId":"123","placeId":"456"}), patch.object(readiness,"run_task") as task:
                self.assertEqual(readiness.main(["--output",str(out)]),2)
                task.assert_not_called()
