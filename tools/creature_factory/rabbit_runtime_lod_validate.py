"""Independently gate the reduced rabbit GLB / UV / skin / silhouette vs the master.
No 'gameplay PASS' claim: checks are asset-only on GitHub runner.
"""
import argparse,io,hashlib,json,struct
from pathlib import Path
import numpy as np
from PIL import Image

MAX_PER_MESH=20_000
MAX_TOTAL=20_000
EXPECTED_BONES={'Root','Pelvis','Chest','Head','Ear_L','Ear_R','Shoulder_L','Shoulder_R',
                'Forearm_L','Forearm_R','FrontPaw_L','FrontPaw_R','Hip_L','Hip_R',
                'Shin_L','Shin_R','HindPaw_L','HindPaw_R','Tail'}
VIEWS=('front','right','left','back','top','three-quarter')

def glb(path):
    buf=Path(path).read_bytes()
    assert buf[:4]==b'glTF' and struct.unpack_from('<I',buf,4)[0]==2
    assert struct.unpack_from('<I',buf,8)[0]==len(buf)
    jlen,jtype=struct.unpack_from('<II',buf,12)
    assert jtype==0x4e4f534a
    data=json.loads(buf[20:20+jlen]);start=20+jlen
    blen,btype=struct.unpack_from('<II',buf,start)
    assert btype==0x004e4942
    blob=buf[start+8:start+8+blen]
    return data,blob

def read_accessor(doc,blob,idx):
    acc=doc['accessors'][idx];vw=doc['bufferViews'][acc['bufferView']]
    types={5126:'<f4',5125:'<u4',5123:'<u2',5121:'u1'}
    shape={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}
    dt=np.dtype(types[acc['componentType']]);components=shape[acc['type']]
    start=vw.get('byteOffset',0)+acc.get('byteOffset',0)
    return np.ndarray((acc['count'],components),dtype=dt,buffer=blob,offset=start,
                      strides=(vw.get('byteStride',dt.itemsize*components),dt.itemsize)).copy()

def verify(source,optimized,report_path,outdir):
    src,srcbin=glb(source);dst,dstbin=glb(optimized)
    build=json.loads(Path(report_path).read_text())
    assert len(src['skins'])==len(dst['skins'])==1
    assert len(src['meshes'])==len(dst['meshes'])==9
    assert len(dst.get('images',[]))==1 and len(dst['materials'])==1
    bone_names={dst['nodes'][i]['name'] for i in dst['skins'][0]['joints']}
    assert bone_names==EXPECTED_BONES, sorted(bone_names^EXPECTED_BONES)
    source_mesh={m['name']:m for m in src['meshes']}
    names=[];triangles=0;details={}
    for mesh in dst['meshes']:
        n=mesh['name'];names.append(n)
        assert n in source_mesh and mesh['primitives'],n
        vcount=0;tricount=0;uv_min=10;uv_max=-10;weight_min=10;weight_max=-10
        for prim in mesh['primitives']:
            a=prim['attributes']
            assert {'POSITION','NORMAL','TEXCOORD_0','JOINTS_0','WEIGHTS_0'} <= set(a),n
            verts=read_accessor(dst,dstbin,a['POSITION'])
            uvs=read_accessor(dst,dstbin,a['TEXCOORD_0'])
            normals=read_accessor(dst,dstbin,a['NORMAL'])
            weights=read_accessor(dst,dstbin,a['WEIGHTS_0'])
            joint_indices=read_accessor(dst,dstbin,a['JOINTS_0'])
            faces=read_accessor(dst,dstbin,prim['indices']).ravel()
            assert len(faces)%3==0
            assert faces.max()<len(verts)
            assert len(verts)==len(uvs)==len(normals)==len(weights)==len(joint_indices)
            assert np.isfinite(verts).all() and np.isfinite(uvs).all()
            assert np.isfinite(normals).all() and np.isfinite(weights).all()
            assert joint_indices.max()<len(dst['skins'][0]['joints'])
            uv_min=min(uv_min,float(uvs.min()));uv_max=max(uv_max,float(uvs.max()))
            weight_sums=weights.sum(axis=1)
            weight_min=min(weight_min,float(weight_sums.min()));weight_max=max(weight_max,float(weight_sums.max()))
            assert 0.98<weight_min and weight_max<1.02,(n,weight_min,weight_max)
            tricount+=len(faces)//3;vcount+=len(verts)
        assert 0<=uv_min and uv_max<=1,(n,uv_min,uv_max)
        assert 0<tricount<=MAX_PER_MESH,(n,tricount)
        if n.startswith('Whisker_'):
            src_tri=sum(src['accessors'][p['indices']]['count']//3 for p in source_mesh[n]['primitives'])
            assert tricount==src_tri,(n,'whisker lost triangles')
        triangles+=tricount
        details[n]={'triangles':tricount,'vertices':vcount,'uv_range':[uv_min,uv_max],
                    'weights_sum_range':[weight_min,weight_max]}
    assert len([n for n in names if n.startswith('Whisker_')])==6
    assert triangles<=MAX_TOTAL,(triangles,MAX_TOTAL)
    assert triangles<sum(s['accessors'][p['indices']]['count']//3 for m in src['meshes'] for p in m['primitives'])*.4
    assert sum(v['triangles'] for v in build['per_mesh_after'].values())==triangles

    i=dst['images'][0]
    v=dst['bufferViews'][i['bufferView']]
    im=Image.open(io.BytesIO(dstbin[v.get('byteOffset',0):v.get('byteOffset',0)+v['byteLength']]))
    assert im.size==(2048,2048),im.size
    assert dst['materials'][0]['pbrMetallicRoughness']['baseColorTexture']['index']==0

    # Recheck silhouette and shading using actual headless Blender rasterized renders.
    masks={};color_deltas={}
    root=Path(outdir)
    for angle in VIEWS:
        a=np.asarray(Image.open(root/f'master-{angle}.png').convert('RGBA'),dtype=np.uint8)
        b=np.asarray(Image.open(root/f'lod-{angle}.png').convert('RGBA'),dtype=np.uint8)
        assert a.shape==b.shape
        amask=a[:,:,3]>127;bmask=b[:,:,3]>127
        union=np.logical_or(amask,bmask);inter=np.logical_and(amask,bmask)
        assert np.count_nonzero(union)>100
        iou=float(inter.sum()/union.sum());masks[angle]=iou
        # measured only on jointly visible pixels to avoid background artifacts
        delta=np.abs(a[:,:,:3].astype(np.int16)-b[:,:,:3].astype(np.int16))
        color_deltas[angle]=float(delta[inter].mean()) if np.any(inter) else 255
        assert iou>=.96,(angle,'silhouette_iou',iou)
        assert color_deltas[angle]<35,(angle,'mean RGB difference',color_deltas[angle])

    assert len(build['pose_probes'])>=5
    assert all(p['max_vertex_displacement']>.01 for p in build['pose_probes'].values())
    result={'status':'PASS_ASSET_ONLY','roblox_runtime_validated':False,
            'source_sha256':hashlib.sha256(Path(source).read_bytes()).hexdigest(),
            'runtime_sha256':hashlib.sha256(Path(optimized).read_bytes()).hexdigest(),
            'bone_count':len(bone_names),'whiskers':6,'per_mesh':details,
            'triangles_total':triangles,'triangle_reduction_percent':round(100*(1-triangles/60968),2),
            'silhouette_iou':masks,'mean_rgb_delta':color_deltas,
            'texture_dimensions':[2048,2048],'pose_probes':build['pose_probes'],
            'limitations':['No actual Roblox Studio import, joint skin playback or mobile client measured.',
                           'Approval of the runtime appearance requires owner review of side-by-side renders.']}
    (root/'validation.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2),flush=True)
    return result

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('master_glb');p.add_argument('runtime_glb');p.add_argument('build_report');p.add_argument('output_dir')
    a=p.parse_args()
    verify(a.master_glb,a.runtime_glb,a.build_report,a.output_dir)