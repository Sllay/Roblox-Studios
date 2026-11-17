"""Author six original rabbit skeletal clips as native Roblox KeyframeSequences.

This produces animation-source XML only; Roblox moderation, ownership, and playback
must be confirmed separately. The published GLB's 19-bone hierarchy is the source
of truth, not an approximated concept sheet.
"""
from __future__ import annotations
import argparse,hashlib,json,math,struct,xml.etree.ElementTree as ET
from pathlib import Path

CLIPS={
 'Idle':(3.0,18,True,0),
 'Walk':(1.2,16,True,1),
 'Run':(.72,18,True,1),
 'Peck':(1.4,16,False,2),
 'Flap':(1.45,16,False,2),
 'Death':(1.0,14,False,2),
}
EXPECTED={'Root','Pelvis','Chest','Head','Ear_L','Ear_R','Shoulder_L','Shoulder_R','Forearm_L','Forearm_R','FrontPaw_L','FrontPaw_R','Hip_L','Hip_R','Shin_L','Shin_R','HindPaw_L','HindPaw_R','Tail'}

def prop(parent, tag, name, value):
    el=ET.SubElement(parent,tag,name=name);el.text=str(value);return el

def item(parent,cls,name):
    el=ET.SubElement(parent,'Item',{'class':cls});p=ET.SubElement(el,'Properties');prop(p,'string','Name',name);return el,p

def cframe_xyz(ax=0,ay=0,az=0,y=0):
    # Roblox CoordinateFrame rotation: Rz(az) @ Ry(ay) @ Rx(ax)
    cx,sx=math.cos(ax),math.sin(ax)
    cy,sy=math.cos(ay),math.sin(ay)
    cz,sz=math.cos(az),math.sin(az)
    return (0,y,0,cz*cy,cz*sy*sx-sz*cx,cz*sy*cx+sz*sx,
            sz*cy,sz*sy*sx+cz*cx,sz*sy*cx-cz*sx,
            -sy,cy*sx,cy*cx)

def motion(clip, name, t):
    # Small organic motions, expressed in each bone's own local joint frame.
    # Time t always [0,1] for looping, or an authored one-shot timeline.
    tau=2*math.pi*t; s=math.sin(tau); c=math.cos(tau)
    phase={'L':0.0,'R':math.pi}
    ax=ay=az=y=0.0
    if clip=='Idle':
        breath=.025*math.sin(tau)
        if name=='Chest': ax=breath
        if name=='Head': ax=.028*math.sin(tau+.6);az=.017*math.sin(tau*.5)
        if name.startswith('Ear_'): az=(1 if name.endswith('L') else -1)*(.025+.024*math.sin(tau+.25))
        if name=='Tail': ay=.028*math.sin(tau+.5)
    elif clip=='Walk':
        if name=='Root': y=.035*max(0,math.sin(2*tau))
        if name=='Chest':ax=.04*math.sin(tau+.3)
        if name=='Head':ax=.05*math.sin(tau+.6)
        if name.startswith(('Hip_','Shoulder_')):
            side=name.rsplit('_',1)[-1];ax=.18*math.sin(tau+phase[side])
        if name.startswith(('Shin_','Forearm_')):
            side=name.rsplit('_',1)[-1];ax=.12*math.sin(tau+phase[side]+.8)
        if name.startswith('Ear_'): az=(1 if name.endswith('L') else -1)*(.06*math.sin(tau+.8))
    elif clip=='Run':
        jump=max(0,math.sin(tau))
        if name=='Root':y=.20*jump*jump
        if name=='Chest':ax=.16*math.sin(tau+.35)
        if name=='Head':ax=-.085*math.sin(tau-.12)
        if name.startswith('Hip_'):ax=-.34*math.sin(tau-.45)
        if name.startswith('Shin_'):ax=.43*math.sin(tau+.20)
        if name.startswith('HindPaw_'):ax=-.15*math.sin(tau+.40)
        if name.startswith('Shoulder_'):ax=.28*math.sin(tau+.55)
        if name.startswith('Forearm_'):ax=.22*math.sin(tau+.20)
        if name.startswith('Ear_'): ax=.16*math.sin(tau-1.0)
    elif clip=='Peck':
        env=(math.sin(math.pi*t))**2
        pulses=.5+.5*math.sin(4*math.pi*t-.5)
        if name=='Head':ax=.31*env*pulses
        if name=='Chest':ax=.12*env
        if name.startswith('Forearm_'):ax=-.14*env
        if name.startswith('Ear_'):ax=-.075*env
    elif clip=='Flap':
        # Adapter's shared "Flap" state is an alert/perk-ear behavior for rabbits.
        env=math.sin(math.pi*t)**2
        if name=='Head':ax=-.11*env;az=.08*env
        if name.startswith('Ear_'):ax=-.18*env;az=(1 if name.endswith('L') else -1)*.15*env
        if name=='Chest':ax=-.055*env
    elif clip=='Death':
        # Hit/lifecycle: visual collapse, actual death physics still handled by RobloxMobAdapter.
        env=t*t*(3-2*t)
        if name=='Pelvis':az=.18*env
        if name=='Chest':ax=.25*env
        if name=='Head':ax=.30*env
        if name.startswith('Ear_'):ax=.45*env
        if name.startswith('Shoulder_'):ax=.30*env
    return cframe_xyz(ax,ay,az,y)

def main():
    ap=argparse.ArgumentParser();ap.add_argument('source_glb',type=Path);ap.add_argument('out_dir',type=Path);a=ap.parse_args()
    data=a.source_glb.read_bytes();assert data[:4]==b'glTF'
    n=struct.unpack_from('<I',data,12)[0];doc=json.loads(data[20:20+n]);skin=doc['skins'][0];nodes=doc['nodes'];ids=set(skin['joints'])
    names={i:nodes[i]['name'] for i in ids};assert set(names.values())==EXPECTED
    parents={child:i for i in ids for child in nodes[i].get('children',[]) if child in ids}
    roots=[i for i in ids if i not in parents];assert len(roots)==1 and names[roots[0]]=='Root'
    assert len(doc['meshes'])==9
    a.out_dir.mkdir(parents=True,exist_ok=True)
    manifest={}
    for clip,(duration,frames,loop,priority) in CLIPS.items():
        root=ET.Element('roblox',{'version':'4','xmlns:xmime':'http://www.w3.org/2005/05/xmlmime','xmlns:xsi':'http://www.w3.org/2001/XMLSchema-instance'})
        ET.SubElement(root,'External').text='null';ET.SubElement(root,'External').text='nil'
        seq,sp=item(root,'KeyframeSequence',clip);prop(sp,'bool','Loop',str(loop).lower());prop(sp,'token','Priority',priority)
        travel=0.0
        def pose(parent,name,mat):
            obj,props=item(parent,'Pose',name);e=ET.SubElement(props,'CoordinateFrame',name='CFrame')
            for key,val in zip(('X','Y','Z','R00','R01','R02','R10','R11','R12','R20','R21','R22'),mat):ET.SubElement(e,key).text=format(val,'.11g')
            prop(props,'float','Weight',1);prop(props,'token','EasingStyle',0);prop(props,'token','EasingDirection',0)
            return obj
        for f in range(frames+1):
            t=f/frames
            frame,props=item(seq,'Keyframe',f'Frame_{f:03d}');prop(props,'float','Time',format(duration*t,'.10g'))
            wrapper=pose(frame,'RootPart',cframe_xyz())
            def add(node,parent):
                nonlocal travel
                mat=motion(clip,names[node],t)
                travel=max(travel,max(abs(mat[q]-(1 if q in (3,7,11) else 0)) for q in range(12)))
                entry=pose(parent,names[node],mat)
                for child in nodes[node].get('children',[]):
                    if child in ids:add(child,entry)
            add(roots[0],wrapper)
        path=a.out_dir/(clip.lower()+'.rbxmx');ET.ElementTree(root).write(path,encoding='utf-8',xml_declaration=True)
        xml=ET.parse(path).getroot();allFrames=xml.findall('.//Item[@class="Keyframe"]')
        assert len(allFrames)==frames+1
        assert all(len(f.findall('.//Item[@class="Pose"]'))==20 for f in allFrames)
        assert travel>.01,clip
        manifest[clip]={'file':path.name,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'bytes':path.stat().st_size,'frames':frames+1,'duration':duration,'loop':loop,'priority':priority,'poseCount':20,'maxMotionComponent':travel}
    (a.out_dir/'manifest.json').write_text(json.dumps({'schema':1,'source_glb_sha256':hashlib.sha256(data).hexdigest(),'rig_bones':19,'clips':manifest,'stage':'authored_unpublished'},indent=2)+'\n')
    print('RABBIT_ANIMATIONS_AUTHORED',json.dumps(manifest))
if __name__=='__main__':main()