"""Run village domain suites and synthetic DataStore in a disposable v19 session."""

import json
import os
from pathlib import Path
import re

from cloud_tasks import run_task

GAME = Path("games/maps/entre-reinos")
MODULES = GAME / "game/places/main/src/ReplicatedStorage"
TESTS = GAME / "game/tests"


def bundle_source():
    definitions = []
    require = re.compile(r'require\("([./][^"]*)"\)')
    def candidate(source):
        return require.sub(lambda m: f'loadCandidate("{Path(m[1]).name}")', source)

    names = set()
    for file in sorted(MODULES.rglob("*.luau")):
        if file.stem in names:
            raise ValueError(f"Ambiguous module {file.stem}")
        names.add(file.stem)
        definitions.append(f'modules["{file.stem}"] = function()\n{candidate(file.read_text())}\nend')

    saves = (MODULES.parent / "ServerScriptService/Services/SaveSlotService.luau").read_text()
    for variable, name in {
        "Slots": "SlotModel", "WorldProfile": "WorldProfile", "Policy": "SlotLeasePolicy",
        "LivingModel": "LivingModel", "Regions": "RegionalWorld",
    }.items():
        saves, count = re.subn(rf'local {variable} = require\(ReplicatedStorage[^\n]*(?:\n[^\n]*LivingModel"\)\))?',
                               f'local {variable} = loadCandidate("{name}")', saves, count=1)
        assert count == 1, variable

    tests = ("production", "food", "market", "relationships", "regions")
    suites = [
        f'local start_{name}=os.clock()\ndo\n{candidate((TESTS / f"society_{name}.luau").read_text())}\nend\n'
        f'report.milliseconds["{name}"]=(os.clock()-start_{name})*1000'
        for name in tests
    ]
    return "\n".join([
        'assert(game.PlaceVersion==19,"Unexpected published staging baseline")',
        'local modules,cache={},{}',
        'local function loadCandidate(name)\n'
        ' if cache[name]==nil then cache[name]=assert(modules[name],name)() end\n'
        ' return cache[name]\nend',
        *definitions,
        f'local function loadSaveService(game)\n{saves}\nend',
        'local report={universeId=tostring(game.GameId),placeId=tostring(game.PlaceId),milliseconds={}}',
        *suites,
        f'local function datastoreProbe()\n{(TESTS / "staging_society_datastore.luau").read_text()}\nend',
        'report.datastore=datastoreProbe()',
        'return game:GetService("HttpService"):JSONEncode(report)',
    ])


if __name__ == "__main__":
    cfg = json.loads((GAME / "deploy.targets.json").read_text())["environments"]["staging"]
    assert cfg["universeId"] == "10769712413" and cfg["placeIds"]["main"] == "90623742498445"
    result = run_task(cfg["universeId"], cfg["placeIds"]["main"],
                      os.environ["ROBLOX_OPEN_CLOUD_API_KEY"], bundle_source())
    assert result["loadedVersion"] == 19
    assert result["datastore"]["backupRestored"] and result["datastore"]["replyRetry"]
    assert result["datastore"]["newRuleset"] == 5
    print("ENTRE_REINOS_T2_R2_PROBE", json.dumps(result, sort_keys=True))
