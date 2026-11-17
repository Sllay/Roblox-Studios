"""Validate serialized C1 artifacts against versioned JSON Schema.
Runtime cross-field and file constraints stay in contracts.py.
"""
import json,sys
from pathlib import Path
from jsonschema import Draft202012Validator
def check(root,job):
    schema=json.loads((Path(__file__).parent/"schemas/v1.json").read_text())
    Draft202012Validator.check_schema(schema)
    def validate(name,data):
        Draft202012Validator({**schema,"$ref":"#/$defs/"+name}).validate(data)
    count=0
    for p in sorted(Path(root).glob("*/manifest.json")):
        validate("AssetManifest",json.loads(p.read_text()));count+=1
        validate("GeometryArtifact",json.loads((p.parent/"artifact.json").read_text()));count+=1
        for e in json.loads((p.parent/"evidence.json").read_text())["views"]:
            validate("EvidenceBundle",e);count+=1
    validate("JobManifest",json.loads((Path(job)/"job.json").read_text()));count+=1
    print(f"Validated {count} serialized contracts")
    return count
if __name__=="__main__":check(sys.argv[1],sys.argv[2])
