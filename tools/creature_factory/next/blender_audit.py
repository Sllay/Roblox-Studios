"""Read-only, species-independent C0 measurements and CPU renders of an existing GLB.

Run with Blender's Python, not the host interpreter. All writes go to --out.
Topology is reported both as imported and after diagnostic position welding; the
second is an estimate because coincident, intentionally separate shells can weld.
Depth and normals describe the imported mesh, never ground truth for concept art.
"""
from __future__ import annotations

import argparse
from collections import Counter
import hashlib
import json
import math
from pathlib import Path
import resource
import struct
import sys
import time

import bmesh
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree
import numpy as np


VIEWS = {
    "front": (0, -1, 0),
    "right": (1, 0, 0),
    "back": (0, 1, 0),
    "three-quarter": (-1, -1, .25),
}


def percentile(values, q):
    return float(np.percentile(values, q)) if len(values) else None


def write_json(path, data):
    path.write_text(json.dumps(data, indent=2, allow_nan=False) + "\n")


def save_png(path, rgba):
    """Save a diagnostic image without depending on Pillow in Blender's Python."""
    rgba = np.asarray(rgba, dtype=np.float32)
    image = bpy.data.images.new(path.stem, width=rgba.shape[1], height=rgba.shape[0], alpha=True)
    image.colorspace_settings.name = "Non-Color"
    image.pixels.foreach_set(np.flipud(rgba).ravel())
    image.filepath_raw = str(path)
    image.file_format = "PNG"
    image.save()
    bpy.data.images.remove(image)


def glb_counts(source):
    with source.open("rb") as stream:
        header = stream.read(20)
        magic, version, length, json_size, kind = struct.unpack("<5I", header)
        if magic != 0x46546C67 or version != 2 or kind != 0x4E4F534A or length != source.stat().st_size:
            raise ValueError("Invalid GLB 2 header")
        data = json.loads(stream.read(json_size))
    primitives = [p for mesh in data.get("meshes", []) for p in mesh["primitives"]]
    accessors = data.get("accessors", [])
    mesh_triangle_counts = [
        sum(accessors[p["indices"]]["count"] // 3 if "indices" in p else accessors[p["attributes"]["POSITION"]]["count"] // 3
            for p in mesh["primitives"] if p.get("mode", 4) == 4)
        for mesh in data.get("meshes", [])
    ]
    selected_scene_triangles = None
    if data.get("scenes"):
        selected = data["scenes"][data.get("scene", 0)]
        pending = list(selected.get("nodes", []))
        selected_scene_triangles = 0
        visited = set()
        while pending:
            node_index = pending.pop()
            if node_index in visited:
                raise ValueError("Repeated or cyclic glTF scene node")
            visited.add(node_index)
            node = data["nodes"][node_index]
            if "mesh" in node:
                selected_scene_triangles += mesh_triangle_counts[node["mesh"]]
            pending.extend(node.get("children", []))
    return {
        "triangles": sum(mesh_triangle_counts),
        "vertices": sum(accessors[p["attributes"]["POSITION"]]["count"] for p in primitives),
        "meshDefinitions": len(data.get("meshes", [])),
        "primitiveDefinitions": len(primitives),
        "skinJointCounts": [len(s["joints"]) for s in data.get("skins", [])],
        "selectedSceneTriangles": selected_scene_triangles,
        "trianglePrimitivesOnly": all(p.get("mode", 4) == 4 for p in primitives),
        "scope": "GLB accessor counts per primitive definition; instances are measured separately in imported meshes",
    }


def remove_display_helpers():
    """Remove importer bone display meshes by role and hidden-collection flags.

    Blender's glTF importer creates an armature custom-shape mesh in a hidden
    non-exported collection. It is present in scene.objects but is not source
    geometry. A name filter would also remove legitimate source meshes.
    """
    shapes = {
        bone.custom_shape
        for obj in bpy.context.scene.objects if obj.type == "ARMATURE"
        for bone in obj.pose.bones if bone.custom_shape is not None
    }
    excluded = []
    for obj in shapes:
        if obj.type != "MESH" or not obj.users_collection:
            continue
        if not all(collection.hide_render and collection.hide_viewport for collection in obj.users_collection):
            continue
        obj.data.calc_loop_triangles()
        excluded.append({
            "name": obj.name,
            "vertices": len(obj.data.vertices),
            "triangles": len(obj.data.loop_triangles),
            "reason": "armature pose-bone custom_shape referenced only through collections hidden for both render and viewport",
            "collections": [{"name": c.name, "hideRender": bool(c.hide_render), "hideViewport": bool(c.hide_viewport)} for c in obj.users_collection],
        })
        bpy.data.objects.remove(obj, do_unlink=True)
    return excluded


def connected_components(bm):
    visited = set()
    sizes = []
    for vertex in bm.verts:
        if vertex in visited:
            continue
        stack = [vertex]
        visited.add(vertex)
        count = 0
        while stack:
            item = stack.pop()
            count += 1
            for edge in item.link_edges:
                other = edge.other_vert(item)
                if other not in visited:
                    visited.add(other)
                    stack.append(other)
        sizes.append(count)
    return sizes


def topology(mesh, tolerance):
    bm = bmesh.new()
    bm.from_mesh(mesh)
    def measure():
        sizes = connected_components(bm)
        return {
            "components": len(sizes),
            "componentVertexCounts": sorted(sizes, reverse=True),
            "boundaryEdges": sum(e.is_boundary for e in bm.edges),
            "nonmanifoldEdges": sum(not e.is_manifold for e in bm.edges),
            "edgesWithMoreThanTwoFaces": sum(len(e.link_faces) > 2 for e in bm.edges),
            "looseVertices": sum(not v.link_edges for v in bm.verts),
            "vertices": len(bm.verts),
            "edges": len(bm.edges),
            "faces": len(bm.faces),
            "euler": len(bm.verts) - len(bm.edges) + len(bm.faces),
        }
    raw = measure()
    bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=tolerance)
    welded = measure()
    bm.free()
    return {"imported": raw, "positionWeldDiagnostic": welded, "weldToleranceLocalUnits": tolerance}


def uv_metrics(mesh, tolerance):
    if not mesh.uv_layers.active:
        return {"available": False, "reason": "No TEXCOORD_0 / active UV map"}, []
    layer = mesh.uv_layers.active.data
    count = len(mesh.loop_triangles)
    parent = list(range(count))
    def root(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i
    def join(a, b):
        a, b = root(a), root(b)
        parent[b] = a
    edge_faces = {}
    stretch, density, areas = [], [], []
    collapsed = outside = nonfinite = 0
    wire = []
    for ti, tri in enumerate(mesh.loop_triangles):
        uv = [np.array(layer[i].uv[:], dtype=np.float64) for i in tri.loops]
        pos = [np.array(mesh.vertices[i].co[:], dtype=np.float64) for i in tri.vertices]
        if not all(np.isfinite(v).all() for v in uv):
            nonfinite += 1
            continue
        wire.append(uv)
        outside += int(any((v < -1e-6).any() or (v > 1 + 1e-6).any() for v in uv))
        uv_area = abs(float(np.linalg.det(np.stack((uv[1] - uv[0], uv[2] - uv[0]))))) / 2
        world_area = float(np.linalg.norm(np.cross(pos[1] - pos[0], pos[2] - pos[0]))) / 2
        areas.append(uv_area)
        if uv_area <= 1e-12 or world_area <= tolerance * tolerance:
            collapsed += 1
        else:
            a, b = pos[1] - pos[0], pos[2] - pos[0]
            length = np.linalg.norm(a)
            x = float(np.dot(b, a) / length)
            y = 2 * world_area / length
            jacobian = np.column_stack(((uv[1] - uv[0]) / length, ((uv[2] - uv[0]) - (uv[1] - uv[0]) / length * x) / y))
            singular = np.linalg.svd(jacobian, compute_uv=False)
            stretch.append(float(singular[0] / singular[1]))
            density.append(math.sqrt(uv_area / world_area))
        # Match both position and UV on each endpoint. Unlike index adjacency,
        # this does not turn a glTF material/normal split into a false UV seam.
        corners = [tuple(np.rint(v / tolerance).astype(np.int64)) + tuple(np.rint(u / 1e-6).astype(np.int64)) for v, u in zip(pos, uv)]
        for a, b in zip(corners, corners[1:] + corners[:1]):
            key = tuple(sorted((a, b)))
            if key in edge_faces:
                join(ti, edge_faces[key])
            else:
                edge_faces[key] = ti
    charts = Counter(root(i) for i in range(count))
    return {
        "available": True,
        "charts": len(charts),
        "chartTriangleCounts": sorted(charts.values(), reverse=True),
        "chartsUnderFourTriangles": sum(n < 4 for n in charts.values()),
        "nonfiniteFaces": nonfinite,
        "collapsedOrNearDegenerateFaces": collapsed,
        "outsideUnitSquareFaces": outside,
        "summedTriangleArea": float(sum(areas)),
        "stretchSingularRatioP50": percentile(stretch, 50),
        "stretchSingularRatioP95": percentile(stretch, 95),
        "densityUVUnitsPerLocalUnitP05": percentile(density, 5),
        "densityUVUnitsPerLocalUnitP95": percentile(density, 95),
        "chartAdjacency": "quantized position endpoints (weld tolerance) plus UV endpoints (1e-6); per object, ignoring material and normal seams",
        "overlap": {"status": "not_measured", "reason": "C0 chart audit is not a positive-area UV overlap validator; historical reports remain separate evidence"},
    }, wire


def mesh_metrics(obj):
    mesh = obj.data
    mesh.calc_loop_triangles()
    points = np.array([v.co[:] for v in mesh.vertices], dtype=np.float64)
    finite = np.isfinite(points).all(axis=1)
    if not finite.all():
        raise ValueError("Nonfinite mesh positions: " + obj.name)
    diagonal = float(np.linalg.norm(points.max(axis=0) - points.min(axis=0))) if len(points) else 0.
    tolerance = max(diagonal * 1e-7, 1e-10)
    face_areas = [float((mesh.vertices[t.vertices[1]].co - mesh.vertices[t.vertices[0]].co).cross(mesh.vertices[t.vertices[2]].co - mesh.vertices[t.vertices[0]].co).length) / 2 for t in mesh.loop_triangles]
    uv, wire = uv_metrics(mesh, tolerance)
    rigged = any(m.type == "ARMATURE" and m.object for m in obj.modifiers)
    invalid_weights = unweighted = 0
    if rigged:
        for vertex in mesh.vertices:
            weights = [float(g.weight) for g in vertex.groups]
            unweighted += int(not weights or sum(weights) <= 0)
            invalid_weights += int(any(not math.isfinite(w) or w < 0 for w in weights) or abs(sum(weights) - 1) > 1e-4)
    return {
        "name": obj.name,
        "vertices": len(mesh.vertices),
        "triangles": len(mesh.loop_triangles),
        "finiteVertices": int(finite.sum()),
        "exactZeroAreaTriangles": sum(a == 0 for a in face_areas),
        "nearDegenerateTriangles": sum(a <= diagonal * diagonal * 1e-12 for a in face_areas),
        "nearDegenerateAreaThresholdLocalUnitsSquared": diagonal * diagonal * 1e-12,
        "topology": topology(mesh, tolerance),
        "uv": uv,
        "weights": {"rigged": rigged, "invalidOrNotNormalizedVertices": invalid_weights if rigged else None, "unweightedVertices": unweighted if rigged else None},
        "robloxTrianglePackaging": {"meshLimit": 20000, "exceedsLimit": len(mesh.loop_triangles) > 20000, "scope": "informational per imported mesh; never a master artistic quality cap"},
    }, wire


def uv_wire(path, triangles, size=512):
    pixels = np.ones((size, size, 4), dtype=np.float32)
    pixels[:, :, :3] = .04
    for triangle in triangles:
        for a, b in zip(triangle, triangle[1:] + triangle[:1]):
            if not np.isfinite(a).all() or not np.isfinite(b).all():
                continue
            a = np.clip(a, 0, 1) * (size - 1)
            b = np.clip(b, 0, 1) * (size - 1)
            n = max(2, int(np.max(np.abs(b - a))) + 1)
            p = np.rint(np.linspace(a, b, n)).astype(int)
            pixels[size - 1 - p[:, 1], p[:, 0], :3] = .9
    save_png(path, pixels)


def make_material(name, checker=False):
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    bsdf = material.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (.42, .42, .42, 1)
    bsdf.inputs["Roughness"].default_value = .85
    if checker:
        uv = material.node_tree.nodes.new("ShaderNodeTexCoord")
        tex = material.node_tree.nodes.new("ShaderNodeTexChecker")
        tex.inputs["Scale"].default_value = 24
        tex.inputs["Color1"].default_value = (.08, .2, .7, 1)
        tex.inputs["Color2"].default_value = (.9, .9, .9, 1)
        material.node_tree.links.new(uv.outputs["UV"], tex.inputs["Vector"])
        material.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    return material


def evaluated_points(objects):
    bpy.context.view_layer.update()
    graph = bpy.context.evaluated_depsgraph_get()
    result = {}
    for obj in objects:
        evaluated = obj.evaluated_get(graph)
        mesh = evaluated.to_mesh()
        result[obj.name] = np.array([(evaluated.matrix_world @ v.co)[:] for v in mesh.vertices], dtype=np.float64)
        evaluated.to_mesh_clear()
    return result


def surface_bvh(objects):
    vertices, triangles = [], []
    graph = bpy.context.evaluated_depsgraph_get()
    for obj in objects:
        evaluated = obj.evaluated_get(graph)
        mesh = evaluated.to_mesh()
        mesh.calc_loop_triangles()
        offset = len(vertices)
        vertices.extend(evaluated.matrix_world @ v.co for v in mesh.vertices)
        triangles.extend(tuple(i + offset for i in t.vertices) for t in mesh.loop_triangles)
        evaluated.to_mesh_clear()
    return BVHTree.FromPolygons(vertices, triangles, all_triangles=True)


def geometry_buffers(out, name, camera, bvh, resolution, distance):
    """Center-sampled, no-AA orthographic camera Z depth and geometric normals."""
    depth = np.zeros((resolution, resolution), dtype=np.float32)
    normal = np.zeros((resolution, resolution, 3), dtype=np.float32)
    mask = np.zeros((resolution, resolution), dtype=bool)
    rotation = camera.matrix_world.to_3x3()
    right, up = rotation @ Vector((1, 0, 0)), rotation @ Vector((0, 1, 0))
    direction = (rotation @ Vector((0, 0, -1))).normalized()
    half = camera.data.ortho_scale / 2
    for row in range(resolution):
        y = (1 - 2 * (row + .5) / resolution) * half
        for column in range(resolution):
            x = (2 * (column + .5) / resolution - 1) * half
            origin = camera.location + right * x + up * y
            hit, n, _, length = bvh.ray_cast(origin, direction, distance)
            if hit is not None:
                depth[row, column] = length
                normal[row, column] = n[:]
                mask[row, column] = True
    np.save(out / f"depth-{name}.npy", depth)
    np.save(out / f"normal-{name}.npy", normal)
    np.save(out / f"mask-{name}.npy", mask)
    if not np.isfinite(depth).all() or not np.isfinite(normal).all():
        raise ValueError("Nonfinite geometry buffers: " + name)
    if not mask.any() or not (depth[mask] > 0).all():
        raise ValueError("Camera misses geometry or produces nonpositive depth: " + name)
    if not np.allclose(np.linalg.norm(normal[mask], axis=1), 1, atol=1e-5, rtol=0):
        raise ValueError("Nonunit geometric normals: " + name)
    if (depth[~mask] != 0).any() or (normal[~mask] != 0).any():
        raise ValueError("Background geometry buffers must be zero: " + name)
    rgba = np.zeros((resolution, resolution, 4), dtype=np.float32)
    rgba[mask, :3] = normal[mask] * .5 + .5
    rgba[mask, 3] = 1
    save_png(out / f"normal-{name}.png", rgba)
    values = depth[mask]
    low, high = (float(values.min()), float(values.max())) if len(values) else (0., 0.)
    intensity = 1 - (depth - low) / max(high - low, 1e-8)
    rgba[:, :, :3] = np.where(mask[:, :, None], intensity[:, :, None], 0)
    save_png(out / f"depth-{name}.png", rgba)
    return {"validPixels": int(mask.sum()), "depthMin": low, "depthMax": high,
            "bufferValidation": {"finite": True, "unitNormalsTolerance": 1e-5, "zeroBackground": True, "positiveMaskedDepth": True}}


def setup_scene(objects, resolution):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 32
    scene.cycles.use_denoising = False
    scene.cycles.max_bounces = 3
    scene.render.threads_mode = "FIXED"
    scene.render.threads = 2
    scene.render.resolution_x = resolution
    scene.render.resolution_y = resolution
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.world = bpy.data.worlds.new("AuditWorld")
    scene.world.use_nodes = True
    scene.world.node_tree.nodes["Background"].inputs["Color"].default_value = (.18, .18, .18, 1)
    scene.world.node_tree.nodes["Background"].inputs["Strength"].default_value = .35
    for index, (direction, energy) in enumerate([((1, -2, 3), 2.), ((-2, -1, 1), .8), ((0, 2, 2), 1.2)]):
        light = bpy.data.lights.new("AuditSun" + str(index), "SUN")
        light.energy = energy
        light.angle = math.radians(12)
        obj = bpy.data.objects.new(light.name, light)
        scene.collection.objects.link(obj)
        obj.rotation_euler = (-Vector(direction)).to_track_quat("-Z", "Y").to_euler()
    points = np.concatenate(list(evaluated_points(objects).values()))
    lower, upper = points.min(axis=0), points.max(axis=0)
    center = Vector(((lower + upper) / 2).tolist())
    diagonal = float(np.linalg.norm(upper - lower))
    if not math.isfinite(diagonal) or diagonal <= 0:
        raise ValueError("Empty or nonfinite world-space bounding box")
    camera_data = bpy.data.cameras.new("AuditCamera")
    camera = bpy.data.objects.new("AuditCamera", camera_data)
    scene.collection.objects.link(camera)
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = diagonal * 1.12
    camera_data.clip_start = diagonal * .001
    camera_data.clip_end = diagonal * 10
    scene.camera = camera
    return scene, camera, center, diagonal


def camera_at(camera, center, diagonal, direction):
    camera.location = center + Vector(direction).normalized() * diagonal * 3
    camera.rotation_euler = (center - camera.location).to_track_quat("-Z", "Y").to_euler()
    bpy.context.view_layer.update()


def render(scene, path):
    scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--resolution", type=int, default=256)
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:])
    if not 32 <= args.resolution <= 1024:
        raise ValueError("Audit render resolution must be 32..1024 (execution resource guardrail)")
    source, out = args.source.resolve(), args.out.resolve()
    if source.is_relative_to(out) or out.is_relative_to(source.parent):
        raise ValueError("Audit output must be outside the source asset directory")
    out.mkdir(parents=True, exist_ok=True)
    if any(out.iterdir()):
        raise ValueError("Output directory must be empty; preserve previous audit outputs")
    started = time.monotonic()
    source_hash = hashlib.sha256(source.read_bytes()).hexdigest()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(source))
    excluded_helpers = remove_display_helpers()
    objects = sorted((o for o in bpy.context.scene.objects if o.type == "MESH"), key=lambda o: o.name)
    if not objects:
        raise ValueError("Source contains no mesh objects")
    # Embedded lights must not change the common audit lighting across assets.
    # Removing these imported scene objects changes memory only, never the GLB.
    for obj in list(bpy.context.scene.objects):
        if obj.type in {"LIGHT", "CAMERA"}:
            bpy.data.objects.remove(obj, do_unlink=True)
    report = {"schema": 1, "status": "measuring", "source": str(source), "sourceSha256": source_hash, "sourceBytes": source.stat().st_size,
              "blenderVersion": bpy.app.version_string, "numpyVersion": np.__version__, "glb": glb_counts(source), "meshes": [],
              "excludedDisplayHelpers": {"count": len(excluded_helpers), "objects": excluded_helpers},
              "referenceDepth": {"status": "unavailable", "reason": "Illustrated concepts have no calibrated ground-truth geometry or measured depth"},
              "limitations": ["C0 measurements are observations of preserved candidates, not artistic approval.", "No self-intersection or positive-area UV-overlap test is performed by this worker.", "Diagnostic position welding can merge coincident separate surfaces; raw topology is retained.", "Camera axes use imported Blender world (+Z up, front -Y); concept cameras are not calibrated.", "Depth and geometric world normals are center-sampled from a BVH of evaluated imported geometry, without texture, shading normals or antialiasing.", "Pose probes are generic joint rotations, not anatomy, collision or deformation approval."],
              "artisticApproval": False, "robloxPublished": False}
    wire = []
    for obj in objects:
        metrics, triangles = mesh_metrics(obj)
        report["meshes"].append(metrics)
        wire.extend(triangles)
    report["totals"] = {"triangles": sum(m["triangles"] for m in report["meshes"]), "vertices": sum(m["vertices"] for m in report["meshes"]),
                        "bones": sum(len(o.data.bones) for o in bpy.context.scene.objects if o.type == "ARMATURE"),
                        "uvCharts": sum(m["uv"].get("charts", 0) for m in report["meshes"]),
                        "meshesWithoutUV": sum(not m["uv"]["available"] for m in report["meshes"]),
                        "exactZeroAreaTriangles": sum(m["exactZeroAreaTriangles"] for m in report["meshes"]),
                        "invalidWeightVertices": sum(m["weights"]["invalidOrNotNormalizedVertices"] or 0 for m in report["meshes"])}
    source_triangles = report["glb"]["selectedSceneTriangles"]
    if report["glb"]["trianglePrimitivesOnly"] and source_triangles is not None:
        if report["totals"]["triangles"] != source_triangles:
            raise ValueError(f"Imported triangle count differs from selected source scene: {report['totals']['triangles']} != {source_triangles}")
        report["sourceSceneTriangleCountVerified"] = True
    write_json(out / "metrics.json", report)
    uv_wire(out / "uv-wire.png", wire)
    scene, camera, center, diagonal = setup_scene(objects, args.resolution)
    bvh = surface_bvh(objects)
    clay = make_material("AuditClay")
    checker = make_material("AuditUVChecker", checker=True)
    report["cameras"] = {}
    report["buffers"] = {"depth": "float32 camera-forward Z distance in imported world units; zero outside mask; arrays top-left origin", "normal": "float32 geometric face normal in world coordinates, XYZ, zero outside mask", "depthPng": "per-view min/max normalized visualization, not metric depth", "mask": "bool; center sampled BVH visibility"}
    for name, direction in VIEWS.items():
        camera_at(camera, center, diagonal, direction)
        scene.view_layers[0].material_override = None
        render(scene, out / f"color-{name}.png")
        scene.view_layers[0].material_override = clay
        render(scene, out / f"clay-{name}.png")
        report["cameras"][name] = {"type": "orthographic", "matrixWorld": [list(row) for row in camera.matrix_world], "orthoScale": camera.data.ortho_scale,
                                   **geometry_buffers(out, name, camera, bvh, args.resolution, diagonal * 10)}
    camera_at(camera, center, diagonal, VIEWS["three-quarter"])
    scene.view_layers[0].material_override = checker
    render(scene, out / "uv-checker.png")
    scene.view_layers[0].material_override = clay
    report["poseProbes"] = []
    neutral = evaluated_points(objects)
    for rig in sorted((o for o in bpy.context.scene.objects if o.type == "ARMATURE"), key=lambda o: o.name):
        # Choose the first nonroot deform bone. No species names or semantic guesses.
        bone = next((b for b in rig.pose.bones if b.parent and b.bone.use_deform), None)
        if bone is None:
            continue
        original = bone.matrix_basis.copy()
        bone.rotation_mode = "XYZ"
        bone.rotation_euler.x += math.radians(12)
        posed = evaluated_points(objects)
        displacement = {name: float(np.linalg.norm(posed[name] - values, axis=1).max()) for name, values in neutral.items()}
        render(scene, out / f"pose-{len(report['poseProbes'])}.png")
        report["poseProbes"].append({"rig": rig.name, "bone": bone.name, "rotationLocalXDegrees": 12, "maxWorldDisplacementByMesh": displacement,
                                     "scope": "generic sensitivity probe only; no anatomical or collision validation"})
        bone.matrix_basis = original
        bpy.context.view_layer.update()
    report["status"] = "measured_review_required"
    report["measurements"] = {"elapsedSeconds": round(time.monotonic() - started, 4), "processPeakRssKiB": resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
                              "renderer": "Cycles CPU", "samples": scene.cycles.samples, "threads": scene.render.threads, "resolution": args.resolution}
    if hashlib.sha256(source.read_bytes()).hexdigest() != source_hash:
        raise RuntimeError("Original source changed during read-only audit")
    report["sourceUnchanged"] = True
    write_json(out / "metrics.json", report)
    print("CREATURE_AUDIT " + json.dumps({"status": report["status"], "totals": report["totals"], "measurements": report["measurements"]}), flush=True)


if __name__ == "__main__":
    main()
