"""Run village domain suites and synthetic DataStore in a disposable v23 session."""

import base64
import json
import os
from pathlib import Path
import re
import subprocess
from tempfile import TemporaryDirectory
import xml.etree.ElementTree as ET

from cloud_tasks import run_task

GAME = Path("games/maps/entre-reinos")
MODULES = GAME / "game/places/main/src/ReplicatedStorage"
TESTS = GAME / "game/tests"
BASELINE_VERSION = 23


def vegetation_blob():
    """Bake the exact shippable templates for the unpublished engine fixture."""
    model = (MODULES.parent / "ServerStorage/ERVegetation.rbxmx").resolve()
    with TemporaryDirectory() as directory:
        root = Path(directory)
        project = root / "vegetation.project.json"
        output = root / "vegetation.rbxm"
        project.write_text(json.dumps({"name": "ERVegetation", "tree": {"$path": str(model)}}))
        subprocess.run(["rojo", "build", str(project), "--output", str(output)], check=True)
        return base64.b64encode(output.read_bytes()).decode("ascii")


def verify_candidate_grass():
    """Check the authored Terrain property in the candidate, not the v22 scene."""
    subprocess.run(["python", "tools/workspace.py", "build", "--game", "entre-reinos", "--place", "main"], check=True)
    place = ET.parse("dist/entre-reinos/main.rbxlx")
    terrains = place.findall(".//Item[@class='Terrain']")
    assert len(terrains) == 1 and terrains[0].findtext("Properties/bool[@name='Decoration']") == "true"


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

    services = {}
    for service in ("VegetationScene", "WorldService", "CombatService", "BridgeScene", "VehicleRig", "TravelService", "LivingService"):
        source = (MODULES.parent / f"ServerScriptService/Services/{service}.luau").read_text()
        source = re.sub(
            r'require\([^\n]+:WaitForChild\("([\w]+)"\)\)',
            lambda m: f'assert(loadedServices.{m[1]})' if m[1].endswith("Service") or m[1] in ("BridgeScene", "VehicleRig", "VegetationScene")
            else f'loadCandidate("{m[1]}")',
            source,
        )
        if service == "LivingService":
            source = source.replace("actions.OnServerInvoke=function(", "local function probeAction(")
            # Headless fixture has no network Player to receive the UI event.
            source = source.replace("interaction:FireClient(player,best)", "Service.probeTarget=best")
            source = source.replace("connection=RunService.Heartbeat:Connect(function(dt: number)",
                                    "Service.probeStep=function(dt: number)")
            source = source.replace("    end)\n    player:SetAttribute(\"ER_NPCCount\"", "    end\n    player:SetAttribute(\"ER_NPCCount\"")
            source = source.replace("\nreturn Service", "\nService.probeAction=probeAction\nreturn Service")
        services[service] = f"local function load{service}()\n{source}\nend"

    tests = ("production", "food", "market", "relationships", "regions", "soak")
    suites = [
        f'local start_{name}=os.clock()\ndo\n{candidate((TESTS / f"society_{name}.luau").read_text())}\nend\n'
        f'report.milliseconds["{name}"]=(os.clock()-start_{name})*1000'
        for name in tests
    ]
    return "\n".join([
        f'assert(game.PlaceVersion=={BASELINE_VERSION},"Unexpected published staging baseline")',
        'local modules,cache={},{}',
        'local function loadCandidate(name)\n'
        ' if cache[name]==nil then cache[name]=assert(modules[name],name)() end\n'
        ' return cache[name]\nend',
        *definitions,
        f'local function loadSaveService(game)\n{saves}\nend',
        'local report={universeId=tostring(game.GameId),placeId=tostring(game.PlaceId),milliseconds={}}',
        *suites,
        'local loadedServices={SaveSlotService={}}',
        *services.values(),
        'local serial=game:GetService("SerializationService")',
        f'local vegetationBlob=game:GetService("EncodingService"):Base64Decode(buffer.fromstring("{vegetation_blob()}"))',
        'local templates=serial:DeserializeInstancesAsync(vegetationBlob)',
        'assert(#templates==1 and templates[1].Name=="ERVegetation")',
        'local storage=game:GetService("ServerStorage")',
        'storage:WaitForChild("ERVegetation").Name="ERBaselineVegetation"',
        'templates[1].Parent=storage',
        'loadedServices.VegetationScene=loadVegetationScene()',
        'local world=loadWorldService()',
        'loadedServices.WorldService=world',
        'loadedServices.CombatService=loadCombatService()',
        'loadedServices.BridgeScene=loadBridgeScene()',
        'loadedServices.VehicleRig=loadVehicleRig()',
        'loadedServices.TravelService=loadTravelService()',
        'loadedServices.LivingService=loadLivingService()',
        (TESTS / "staging_v20_refinement.luau").read_text(),
        'report.refinement=probeRefinement(world,loadCandidate("RegionalProfile"),'
        'loadCandidate("SceneryProfile"),loadCombatService(),loadCandidate("LivingModel"),loadCandidate("R3Engine"))',
        (TESTS / "staging_water_bridge.luau").read_text(),
        'report.waterBridge=probeWaterBridge(world,loadCandidate("RegionalProfile"),loadCandidate("RegionalCrossings"),loadBridgeScene())',
        (TESTS / "staging_approved_vegetation.luau").read_text(),
        'report.vegetation=probeApprovedVegetation(world,loadedServices.VegetationScene)',
        (TESTS / "staging_full_bridge.luau").read_text(),
        'report.fullBridge=probeFullBridge(world,loadedServices.LivingService,loadedServices.BridgeScene)',
        f'local function datastoreProbe()\n{(TESTS / "staging_society_datastore.luau").read_text()}\nend',
        'report.datastore=datastoreProbe()',
        'return game:GetService("HttpService"):JSONEncode(report)',
    ])


if __name__ == "__main__":
    cfg = json.loads((GAME / "deploy.targets.json").read_text())["environments"]["staging"]
    assert cfg["universeId"] == "10769712413" and cfg["placeIds"]["main"] == "90623742498445"
    verify_candidate_grass()
    result = run_task(cfg["universeId"], cfg["placeIds"]["main"],
                      os.environ["ROBLOX_OPEN_CLOUD_API_KEY"], bundle_source())
    assert result["loadedVersion"] == BASELINE_VERSION
    assert result["datastore"]["backupRestored"] and result["datastore"]["replyRetry"]
    assert result["datastore"]["newRuleset"] == 5
    assert result["refinement"]["nativeLegacyUnchanged"] == 9216
    assert result["waterBridge"]["lightBuilt"] and result["waterBridge"]["reinforcedBuilt"]
    assert result["waterBridge"]["mountedRoute"] and result["waterBridge"]["solidOnlyObstruction"]
    assert result["fullBridge"]["result"] == "built_both"
    result["vegetation"]["candidateNativeGrass"] = True
    print("ENTRE_REINOS_T2_R2_PROBE", json.dumps(result, sort_keys=True))
