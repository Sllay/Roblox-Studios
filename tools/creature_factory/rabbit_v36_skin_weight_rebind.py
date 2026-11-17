"""Seam-preserving Laplacian skin-weight regularization, REVIEW ONLY.

Changes only Rabbit_Torso JOINTS_0 / WEIGHTS_0 in a new GLB. Positions,
faces, UVs, textures, 19-bone skeleton, whiskers and original GLB remain
byte-identical. No Roblox writes.
"""
from __future__ import annotations
import argparse,hashlib,json,struct
from pathlib import Path
import numpy as np
from scipy.sparse import coo_matrix,diags
from scipy.spatial import cKDTree

TYPE_COMPONENTS={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}
COMPONENT_DTYPES={5121:np.uint8,5123:np.uint16,5125:np.uint32,5126:np.float32}

def decode_glb(source:bytes):
 magic,version,byte_length=struct.unpack_from('<4sII',source,0)
 assert magic==b'glTF' and version==2 and byte_length==len(source)
 length,tag=struct.unpack_from('<I4s',source,12)
 assert tag==b'JSON'
 offset=20+length+8
 bin_length,bin_tag=struct.unpack_from('<I4s',source,20+length)
 assert bin_tag==b'BIN\0' and offset+bin_length==len(source)
 return json.loads(source[20:20+length]),offset

def accessor_array(glb,source:bytearray,bin_offset:int,index:int):
 a=glb['accessors'][index]
 assert 'sparse' not in a
 view=glb['bufferViews'][a['bufferView']]
 dtype=np.dtype(COMPONENT_DTYPES[a['componentType']]).newbyteorder('<')
 channels=TYPE_COMPONENTS[a['type']]
 stride=view.get('byteStride',dtype.itemsize*channels)
 assert stride>=dtype.itemsize*channels
 offset=bin_offset+view.get('byteOffset',0)+a.get('byteOffset',0)
 assert offset+(a['count']-1)*stride+dtype.itemsize*channels<=len(source)
 return np.ndarray(shape=(a['count'],channels),dtype=dtype,buffer=source,
                   offset=offset,strides=(stride,dtype.itemsize))

def welded_groups(vertices:np.ndarray,tolerance:float=1e-5):
 parents=np.arange(len(vertices),dtype=np.int32)
 def find(i):
  while parents[i]!=i:
   parents[i]=parents[parents[i]]
   i=int(parents[i])
  return i
 for a,b in cKDTree(vertices).query_pairs(tolerance,output_type='ndarray'):
  x,y=find(int(a)),find(int(b))
  if x!=y:parents[x]=y
 roots=np.array([find(i) for i in range(len(vertices))],dtype=np.int32)
 _,group=np.unique(roots,return_inverse=True)
 return group

def rebind(source_path:Path,dest_path:Path,iterations:int=180):
 assert source_path.resolve()!=dest_path.resolve(), 'Immutable master'
 raw=source_path.read_bytes();glb,bin_offset=decode_glb(raw)
 assert len(glb.get('skins',[]))==1 and len(glb.get('meshes',[]))==9
 assert len(glb['skins'][0]['joints'])==19
 assert sum(m['name'].startswith('Whisker_') for m in glb['meshes'])==6
 torso=next(m for m in glb['meshes'] if m['name']=='Rabbit_Torso')
 assert len(torso['primitives'])==1
 primitive=torso['primitives'][0];attrs=primitive['attributes']
 original=bytearray(raw)
 vertices=accessor_array(glb,original,bin_offset,attrs['POSITION']).copy().astype(np.float64)
 joint_index=attrs['JOINTS_0'];weight_index=attrs['WEIGHTS_0']
 joints=accessor_array(glb,original,bin_offset,joint_index).copy()
 weights=accessor_array(glb,original,bin_offset,weight_index).copy()
 triangles=accessor_array(glb,original,bin_offset,primitive['indices']).copy().reshape(-1,3)
 assert joints.shape==weights.shape==(len(vertices),4)
 assert joints.dtype==np.uint8 and weights.dtype==np.float32
 assert np.all(joints<19) and np.allclose(weights.sum(1),1,atol=.002)
 group=welded_groups(vertices)
 count=np.bincount(group);groups=len(count)
 original_w=np.zeros((groups,19),dtype=np.float32)
 for i in range(4):np.add.at(original_w,(group,joints[:,i]),weights[:,i])
 original_w/=count[:,None]
 triangles=np.asarray(group[triangles],dtype=np.int32)
 edges=np.concatenate([triangles[:,[0,1]],triangles[:,[1,2]],triangles[:,[2,0]]])
 u=np.r_[edges[:,0],edges[:,1]];v=np.r_[edges[:,1],edges[:,0]]
 graph=coo_matrix((np.ones(len(u),dtype=np.float32),(u,v)),shape=(groups,groups)).tocsr()
 graph.setdiag(0);graph.eliminate_zeros();graph.data[:]=1
 graph=diags(1/np.maximum(1,np.asarray(graph.sum(1)).reshape(-1)))@graph
 current=original_w
 for _ in range(iterations):current=.65*current+.35*(graph@current)
 choice=np.argsort(current,axis=1)[:,-4:][:,::-1]
 chosen=np.take_along_axis(current,choice,axis=1)
 chosen/=chosen.sum(axis=1,keepdims=True)
 new_joints=choice[group].astype(np.uint8)
 new_weights=chosen[group].astype(np.float32)
 assert np.allclose(new_weights.sum(axis=1),1,atol=1e-5)
 assert np.isfinite(new_weights).all() and np.all(new_joints<19)
 changed=np.count_nonzero(np.any(joints!=new_joints,axis=1) |
                          (np.max(np.abs(weights-new_weights),axis=1)>.0001))
 assert changed>0
 output=bytearray(raw)
 accessor_array(glb,output,bin_offset,joint_index)[:]=new_joints
 accessor_array(glb,output,bin_offset,weight_index)[:]=new_weights
 updated,offset=decode_glb(output)
 assert offset==bin_offset and updated==glb and len(output)==len(raw)
 dest_path.parent.mkdir(parents=True,exist_ok=True)
 dest_path.write_bytes(output)
 report={
  'schema':1,'status':'v36_skin_weight_review_only','roblox_uploaded':False,
  'source_sha256':hashlib.sha256(raw).hexdigest(),
  'candidate_sha256':hashlib.sha256(output).hexdigest(),
  'mesh_modified':'Rabbit_Torso','vertices':len(vertices),
  'position_groups':groups,'original_bone_count':19,
  'unchanged_geometry_uv_textures_and_faces':True,
  'changed_weight_vertices':int(changed),
  'smoothing_iterations':iterations,'smoothing_alpha':.35,
  'skin_seams_preserved_by_position_welding':True,
  'note':'Visual and gameplay review required. Never auto-publish.'
 }
 (dest_path.parent/'weight-rebind-report.json').write_text(json.dumps(report,indent=2)+'\n')
 print('RABBIT_V36_SKIN_CANDIDATE',json.dumps(report,sort_keys=True),flush=True)
 return report

def main():
 p=argparse.ArgumentParser()
 p.add_argument('source',type=Path);p.add_argument('output',type=Path)
 p.add_argument('--iterations',type=int,default=180)
 a=p.parse_args();assert 40<=a.iterations<=240
 rebind(a.source,a.output,a.iterations)

if __name__=='__main__':main()
