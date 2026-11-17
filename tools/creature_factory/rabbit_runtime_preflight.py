"""Rabbit/creature GLB preflight for Roblox runtime packaging.

Reads GLB metadata without mutating geometry, UVs or skinning. This gate is
separate from artistic approval and in-game rendering/animation validation.
For promotion, use --require-mesh-budget to reject noncompliant candidates.
"""
import argparse
import json
import struct
from pathlib import Path

ROBLOX_MESH_TRIANGLE_LIMIT = 20_000


def check(path):
    data = Path(path).read_bytes()
    assert len(data) >= 28, 'Truncated GLB'
    magic, version, total = struct.unpack_from('<III', data)
    assert magic == 0x46546C67 and version == 2 and total == len(data), 'Invalid GLB header'
    size, typ = struct.unpack_from('<II', data, 12)
    assert typ == 0x4E4F534A and 20 + size <= len(data), 'Missing GLTF JSON'
    doc = json.loads(data[20:20 + size])
    assert doc.get('meshes') and doc.get('accessors'), 'Missing mesh data'
    meshes = []
    warnings = []
    over = []
    for mesh in doc['meshes']:
        triangles = vertices = 0
        for prim in mesh['primitives']:
            assert prim.get('mode', 4) == 4, 'Only triangle primitives allowed'
            assert 'indices' in prim, 'Triangles must be indexed'
            attrs = prim['attributes']
            for key in ('POSITION', 'NORMAL', 'TEXCOORD_0', 'JOINTS_0', 'WEIGHTS_0'):
                assert key in attrs, f"{mesh.get('name')}: missing {key}"
            triangles += doc['accessors'][prim['indices']]['count'] // 3
            vertices += doc['accessors'][attrs['POSITION']]['count']
        name = mesh.get('name', 'unnamed')
        record = {'name': name, 'triangles': triangles, 'vertices': vertices,
                  'under_triangle_limit': triangles <= ROBLOX_MESH_TRIANGLE_LIMIT}
        meshes.append(record)
        if not record['under_triangle_limit']:
            over.append({'name': name, 'triangles': triangles,
                         'excess': triangles - ROBLOX_MESH_TRIANGLE_LIMIT})
    whiskers = [m['name'] for m in meshes if m['name'].startswith('Whisker_')]
    if len(whiskers) != 6:
        warnings.append('Whisker count is not six')
    if len(doc.get('skins', [])) != 1:
        warnings.append('Expected one shared skin')
    if len(doc.get('images', [])) != 1:
        warnings.append('Expected one texture atlas')
    return {
        'schema': 1,
        'asset': Path(path).name,
        'phase': 'pre_import',
        'mesh_triangle_limit': ROBLOX_MESH_TRIANGLE_LIMIT,
        'total_triangles': sum(x['triangles'] for x in meshes),
        'mesh_count': len(meshes),
        'skin_count': len(doc.get('skins', [])),
        'whisker_count': len(whiskers),
        'texture_count': len(doc.get('images', [])),
        'mesh_budget_pass': not over,
        'ready_for_roblox_runtime': False,  # requires platform and mobile visual tests
        'status': 'mesh_budget_blocked' if over else 'mesh_budget_pass_runtime_unverified',
        'meshes': meshes,
        'blocking_meshes': over,
        'warnings': warnings,
        'required_before_runtime_release': [
            'Create a runtime mesh variant that satisfies the per-mesh limit without destroying the approved artwork',
            'Validate skinning, UV seams, whisker pivots and animated deformation after mesh optimization',
            'Import via the skinned mesh pipeline into a test place and check mobile performance',
        ],
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('glb', type=Path)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--require-mesh-budget', action='store_true')
    args = parser.parse_args()
    report = check(args.glb)
    payload = json.dumps(report, indent=2) + '\n'
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(payload)
    print(payload)
    if args.require_mesh_budget and not report['mesh_budget_pass']:
        raise SystemExit(2)


if __name__ == '__main__':
    main()