"""Verify V2 rabbit GLB against an authoritative UV-published source GLB.

Usage: python rabbit_v2_validate.py ORIGINAL.glb RABBIT_V2.glb rabbit_v2_basecolor_4096.png
This validates production-export invariants, not Roblox gameplay.
"""
import hashlib, io, json, struct, sys
from pathlib import Path
import numpy as np
from PIL import Image

def parse(path):
    data=Path(path).read_bytes()
    magic,version,byte_count=struct.unpack_from('<III',data)
    assert magic==0x46546c67 and version==2 and len(data)==byte_count
    json_len,json_type=struct.unpack_from('<II',data,12)
    assert json_type==0x4e4f534a
    doc=json.loads(data[20:20+json_len])
    pos=20+json_len
    bin_len,bin_type=struct.unpack_from('<II',data,pos)
    assert bin_type==0x004e4942
    chunk=data[pos+8:pos+8+bin_len]
    assert len(chunk)==bin_len and doc['buffers'][0]['byteLength']==bin_len
    return doc,chunk

def accessor(doc,chunk,index):
    a=doc['accessors'][index];view=doc['bufferViews'][a['bufferView']]
    typ={5126:'<f4',5125:'<u4',5123:'<u2',5121:'u1'}[a['componentType']]
    count={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}[a['type']]
    dt=np.dtype(typ)
    return np.ndarray((a['count'],count),dtype=dt,buffer=chunk,
        offset=view.get('byteOffset',0)+a.get('byteOffset',0),
        strides=(view.get('byteStride',dt.itemsize*count),dt.itemsize)).copy()

def verify(source,target,texture):
    s,sbin=parse(source);t,tbin=parse(target)
    assert len(t['images'])==len(t['materials'])==len(t['skins'])==1
    assert len(s['meshes'])==len(t['meshes'])==9
    assert s['skins']==t['skins'] and s['nodes']==t['nodes']
    count=0;coord_max=0.0;coordinates=0
    for sm,tm in zip(s['meshes'],t['meshes']):
        assert len(sm['primitives'])==len(tm['primitives'])
        for sp,tp in zip(sm['primitives'],tm['primitives']):
            assert sp['attributes']==tp['attributes'] and sp['indices']==tp['indices']
            for key in ('POSITION','NORMAL','TEXCOORD_0','JOINTS_0','WEIGHTS_0'):
                assert np.array_equal(accessor(s,sbin,sp['attributes'][key]),
                    accessor(t,tbin,tp['attributes'][key])),key
            si=accessor(s,sbin,sp['indices']);ti=accessor(t,tbin,tp['indices'])
            assert np.array_equal(si,ti)
            count+=len(ti)//3
            u=accessor(t,tbin,tp['attributes']['TEXCOORD_0'])
            assert np.isfinite(u).all() and (u>=0).all() and (u<=1).all()
            coord_max=max(coord_max,float(u.max()));coordinates+=len(u)
    assert count==60968
    assert sum(m['name'].startswith('Whisker_') for m in t['meshes'])==6
    image_info=t['images'][0];bi=t['bufferViews'][image_info['bufferView']]
    img_bin=tbin[bi['byteOffset']:bi['byteOffset']+bi['byteLength']]
    png=Path(texture).read_bytes();assert img_bin==png
    im=Image.open(io.BytesIO(png));assert im.size==(4096,4096)
    return {'status':'PASS','triangles':count,'objects':len(t['meshes']),
        'whiskers':6,'uv_vertices':coordinates,'uv_max':coord_max,
        'skins':len(t['skins']),'atlas_size':list(im.size),'png_embedded_exact':True,
        'source_geometry_uv_rig_exact':True,'roblox_runtime_tested':False,
        'target_sha256':hashlib.sha256(Path(target).read_bytes()).hexdigest(),
        'texture_sha256':hashlib.sha256(png).hexdigest()}

if __name__=='__main__':
    assert len(sys.argv)==4,'original.glb v2.glb v2.png'
    print(json.dumps(verify(*sys.argv[1:]),indent=2))
