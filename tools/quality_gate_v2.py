"""P4 typed gameplay gate; fail closed on missing tool, invalid API/type or logic."""
import os,shutil,subprocess,tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
POLICY=ROOT/"games/maps/mapa-principal/game/places/main/src/ServerScriptService/RSGameplayPolicy.luau"
def main():
    lsp=shutil.which("luau-lsp");vm=shutil.which("luau")
    definitions=os.environ.get("RS_ROBLOX_DEFINITIONS")
    if not lsp or not vm or not definitions or not Path(definitions).is_file():raise SystemExit("P4 toolchain unavailable")
    subprocess.run([lsp,"analyze",f"--definitions={definitions}",str(POLICY)],cwd=ROOT,check=True)
    subprocess.run([vm,str(ROOT/"tests/luau/gameplay_policy.luau")],cwd=ROOT,check=True)
    clock=POLICY.parent.parent/"ReplicatedStorage"/"RSWorldClock.luau"
    subprocess.run([lsp,"analyze",f"--definitions={definitions}",str(clock)],cwd=ROOT,check=True)
    subprocess.run([vm,str(ROOT/"tests/luau/world_clock.luau")],cwd=ROOT,check=True)
    wind=POLICY.parent.parent/"ReplicatedStorage"/"RSWindPolicy.luau"
    subprocess.run([lsp,"analyze",f"--definitions={definitions}",str(wind)],cwd=ROOT,check=True)
    subprocess.run([vm,str(ROOT/"tests/luau/wind_policy.luau")],cwd=ROOT,check=True)
    surface=ROOT/"tools/terrain/surface_fields.luau"
    subprocess.run([lsp,"analyze",f"--definitions={definitions}",str(surface)],cwd=ROOT,check=True)
    subprocess.run([vm,str(ROOT/"tests/luau/surface_fields.luau")],cwd=ROOT,check=True)
    # Strict analyze the portable Entre Reinos core as well as executing its assertions.
    er_modules=ROOT/"games/maps/entre-reinos/game/places/main/src/ReplicatedStorage"
    for module_name in ("WorldProfile.luau", "SlotModel.luau", "SlotLeasePolicy.luau"):
        subprocess.run([lsp,"analyze",f"--definitions={definitions}",str(er_modules/module_name)],cwd=ROOT,check=True)
    # Execute Entre Reinos pure Luau assertions, not merely syntax-check the test file.
    er_test=ROOT/"games/maps/entre-reinos/game/tests/region_and_slots.luau"
    subprocess.run([vm,str(er_test)],cwd=ROOT,check=True)
    with tempfile.TemporaryDirectory() as d:
        p=Path(d)/"bad.luau";p.write_text('--!strict\nlocal bad: number = "not a number"\nprint(bad)\n')
        r=subprocess.run([lsp,"analyze",f"--definitions={definitions}",str(p)],cwd=ROOT,capture_output=True,text=True)
        if r.returncode==0 or "TypeError" not in (r.stdout+r.stderr):raise SystemExit("P4 negative type gate failed")
    print("QUALITY_GATE_V2: Roblox typed policy + world clock + executable Luau assertions + negative type gate passed")
if __name__=="__main__":main()
