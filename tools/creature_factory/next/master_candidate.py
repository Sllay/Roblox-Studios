"""Experimental C3-A master candidate adapter.

Verified legacy checkpoint import, not fresh inference or production master.
A separate generic inference entrypoint can produce the same package format.
"""
from pathlib import Path
import json,shutil,zipfile
from .contracts import require,path_inside,GeometryArtifact
from .audit import sha256,write_json
from dataclasses import asdict

def inspect_mesh(vertices,faces):
    import numpy as np
    require(vertices.ndim==2 and vertices.shape[1]==3 and len(vertices)>3 and np.isfinite(vertices).all(),"Invalid vertices")
    require(faces.ndim==2 and faces.shape[1]==3 and len(faces)>3 and np.issubdtype(faces.dtype,np.integer),"Invalid faces")
    require(faces.min()>=0 and faces.max()<len(vertices),"Face index out of bounds")
    require(np.all((faces[:,0]!=faces[:,1])&(faces[:,1]!=faces[:,2])&(faces[:,0]!=faces[:,2])),"Repeated face index")
    p=vertices[faces];area=np.linalg.norm(np.cross(p[:,1]-p[:,0],p[:,2]-p[:,0]),axis=1)*.5
    edges=np.sort(np.concatenate([faces[:,[0,1]],faces[:,[1,2]],faces[:,[2,0]]]),axis=1)
    _,counts=np.unique(edges,axis=0,return_counts=True)
    return {"vertices":len(vertices),"triangles":len(faces),"bounds":[vertices.min(0).tolist(),vertices.max(0).tolist()],"boundary_edges":int((counts==1).sum()),"nonmanifold_edges":int((counts>2).sum()),"near_zero_area_faces":int((area<1e-10).sum()),"surface_area":float(area.sum())}

def import_checkpoint(m,source,out,cfg,inputs):
    import numpy as np
    import trimesh
    require(cfg.get("backend")=="verified_triposr_checkpoint","Unsupported candidate backend")
    archive=path_inside(source.parent,cfg["archive"])
    require(archive.is_file() and sha256(archive)==cfg["sha256"],"Candidate archive hash mismatch")
    with zipfile.ZipFile(archive) as z:
        require(len(z.namelist())==len(set(z.namelist())),"Duplicate archive member")
        for name in ("neural-report.json","neural-mesh.npz"):
            require(name in z.namelist() and z.getinfo(name).file_size<256*1024*1024,"Missing/oversize checkpoint")
        report=json.loads(z.read("neural-report.json"))
        # Bind all legacy source references to the manifest's actual bytes.
        declared={v.sha256 for v in m.views}
        require(report["model"]["checkpointSHA256"]=="429e2c6b22a0923967459de24d67f05962b235f79cde6b032aa7ed2ffcd970ee","Unexpected neural weights")
        require({r["sha256"] for r in report["sourceReferences"].values()}==declared,"Checkpoint/reference mismatch")
        require(report["topology"]["reductionMethod"]=="none_full_resolution","Checkpoint is not full-resolution master")
        import io
        with np.load(io.BytesIO(z.read("neural-mesh.npz")),allow_pickle=False) as data:
            v=data["master_vertices"].astype(np.float32);f=data["master_faces"].astype(np.int32)
    stats=inspect_mesh(v,f)
    require(stats["triangles"]==report["masterTriangles"] and stats["vertices"]==report["masterVertices"],"Checkpoint counts disagree")
    np.savez_compressed(out/"master.npz",vertices=v,faces=f)
    mesh=trimesh.Trimesh(vertices=v,faces=f,process=False)
    mesh.export(out/"master.glb")
    # Reload actual exported geometry independently.
    from .audit import glb_metadata
    exported=glb_metadata(out/"master.glb")
    require(exported["triangles"]==stats["triangles"],"GLB triangle count changed")
    write_json(out/"geometry.json",asdict(GeometryArtifact("master.glb",sha256(out/"master.glb"),m.units,stats["vertices"],stats["triangles"])))
    write_json(out/"candidate.json",{"schema":1,"status":"experimental_master_candidate","asset_id":m.asset_id,"provenance":report["model"],"source_archive_sha256":cfg["sha256"],"source_references":report["sourceReferences"],"metrics":stats,"fresh_inference":False,"artistic_approval":False,"publication_allowed":False,"limitations":["Restored learned single-image geometry; no new inference or multiview refinement.","Anatomy declarations are not verified geometry.","Production master_ready remains blocked until evidence and quality gates pass."]})
    return {"triangles":stats["triangles"],"vertices":stats["vertices"],"scope":"experimental checkpoint, not production"}
