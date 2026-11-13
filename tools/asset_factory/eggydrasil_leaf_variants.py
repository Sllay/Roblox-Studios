"""Apply two artist-supplied PNGs to a V6 leaf-card asset without changing geometry.
Usage: python eggydrasil_leaf_variants.py SOURCE_DIR LIGHT.png DARK.png OUTPUT_DIR
Requires numpy and Pillow. Source must contain the V6 preview and three canopy LODs.
"""
import argparse,json,struct,hashlib
from pathlib import Path
import numpy as np
from PIL import Image

def read_glb(path):
    b=path.read_bytes();n,k=struct.unpack_from('<II',b,12);assert k==0x4e4f534a
    d=json.loads(b[20:20+n]);size,k=struct.unpack_from('<II',b,20+n);assert k==0x4e4942
    return d,bytearray(b[28+n:28+n+size])
def accessor(d,b,i):
    a=d['accessors'][i];v=d['bufferViews'][a['bufferView']]
    typ={5126:'<f4',5123:'<u2',5125:'<u4',5121:'u1'}[a['componentType']]
    n={'SCALAR':1,'VEC2':2,'VEC3':3}[a['type']]
    assert v.get('byteStride',np.dtype(typ).itemsize*n)==np.dtype(typ).itemsize*n
    return np.frombuffer(b,dtype=typ,count=a['count']*n,offset=v.get('byteOffset',0)+a.get('byteOffset',0)).reshape(-1,n)
def write_glb(path,d,b):
    while len(b)%4:b.append(0)
    d['buffers'][0]['byteLength']=len(b)
    j=json.dumps(d,separators=(',',':')).encode();j+=b' '*(-len(j)%4)
    path.write_bytes(struct.pack('<4sII',b'glTF',2,12+8+len(j)+8+len(b))+struct.pack('<II',len(j),0x4e4f534a)+j+struct.pack('<II',len(b),0x4e4942)+b)
def main():
    p=argparse.ArgumentParser();p.add_argument('source',type=Path);p.add_argument('light',type=Path);p.add_argument('dark',type=Path);p.add_argument('out',type=Path);a=p.parse_args();a.out.mkdir(parents=True,exist_ok=True)
    imgs=[Image.open(x).convert('RGBA') for x in (a.light,a.dark)]
    assert all(im.size==(1024,1024) and im.getchannel('A').getextrema()==(0,255) for im in imgs)
    atlas=Image.new('RGBA',(2048,1024));atlas.paste(imgs[0],(0,0));atlas.paste(imgs[1],(1024,0));atlas.save(a.out/'leaves-atlas.png');png=(a.out/'leaves-atlas.png').read_bytes()
    reports={}
    for name in ['eggydrasil-v6-preview.glb','canopy-lod0.glb','canopy-lod1.glb','canopy-lod2.glb']:
        d,b=read_glb(a.source/name)
        m=next(m for m in d['meshes'] if m['name'].startswith('Canopy'));pr=m['primitives'][0]
        pos=accessor(d,b,pr['attributes']['POSITION']);uv=accessor(d,b,pr['attributes']['TEXCOORD_0']);idx=accessor(d,b,pr['indices']).reshape(-1,6)
        assert len(idx)*2 in (6400,3200,1600)
        seen=set();counts=[0,0]
        # Stable position-based choice keeps card colors consistent across LODs.
        for inds in idx:
            ids=np.unique(inds);unique=np.unique(pos[ids],axis=0)
            assert len(unique)==4 and not seen.intersection(ids);seen.update(ids)
            center=unique.mean(0);h=center[1];radius=np.hypot(center[0],center[2])
            prob=np.clip(.24+.46*(h-12)/39+.20*radius/25,.22,.83)
            key=tuple(np.round(center*1000).astype(int))
            rv=int.from_bytes(hashlib.sha256(str(key).encode()).digest()[:8],'little')/2**64
            dark=int(rv>prob);counts[dark]+=1
            old=uv[ids].copy();norm=(old-old.min(0))/(old.max(0)-old.min(0))
            uv[ids,0]=(norm[:,0]+dark)*.5;uv[ids,1]=norm[:,1]
        assert sum(counts)==len(idx) and min(counts)>0
        del pos,uv,idx
        im=d['images'][0];view=d['bufferViews'][im['bufferView']];offset=len(b);b=bytearray(b)+png
        view.update(byteOffset=offset,byteLength=len(png));im['name']='Jabami_light_dark'
        d['materials'][pr['material']]['name']='Jabami_Leaves_Alpha'
        dest=a.out/name.replace('v6','v7');write_glb(dest,d,b)
        reports[dest.name]={'cards':sum(counts),'light':counts[0],'dark':counts[1]}
    (a.out/'report.json').write_text(json.dumps({'source':'V6 geometry unchanged','textures':{x.name:hashlib.sha256(x.read_bytes()).hexdigest() for x in (a.light,a.dark)},'models':reports},indent=2))
if __name__=='__main__':main()
