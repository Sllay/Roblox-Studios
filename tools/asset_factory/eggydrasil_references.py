"""Procedural, calibrated silhouette references for Eggydrasil V2.
Not artist-drawn references. Each limb is reconstructed separately to reduce ghost volumes.
"""
import argparse,json,math
from pathlib import Path
import numpy as np
from PIL import Image
from scipy.ndimage import binary_fill_holes
def main():
    p=argparse.ArgumentParser();p.add_argument("out",type=Path);a=p.parse_args();out=a.out;out.mkdir(parents=True,exist_ok=True)
    n=128; scale=64.; axis=(np.arange(n)+.5)/n*scale-scale/2
    x,y,z=np.ogrid[:n,:n,:n]; X=axis[x];Y=axis[y];Z=axis[z]+25
    layers=[]; rng=np.random.default_rng(182)
    def add(name,op,pts,radii,flute=0):
        mask=np.zeros((n,n,n),bool)
        for i in range(len(pts)-1):
            A=np.array(pts[i]);B=np.array(pts[i+1]); D=B-A
            t=np.clip(((X-A[0])*D[0]+(Y-A[1])*D[1]+(Z-A[2])*D[2])/np.dot(D,D),0,1)
            dx=X-A[0]-t*D[0];dy=Y-A[1]-t*D[1];dz=Z-A[2]-t*D[2]
            r=radii[i]+t*(radii[i+1]-radii[i])
            if flute:r=r*(1+flute*np.sin(5*np.arctan2(dy,dx)+Z*.24)+.06*np.cos(9*np.arctan2(dy,dx)-Z*.14))
            mask|=dx*dx+dy*dy+dz*dz<=r*r
        if op=='union': mask &= Z>=0
        refs={}
        for k,m in [('front',mask.any(axis=1).T[::-1,:]),('right',mask.any(axis=0).T[::-1,:]),('top',mask.any(axis=2).T[::-1,:])]:
            if not m.any():raise ValueError(name)
            f=name+'-'+k+'.png';Image.fromarray(m.astype('uint8')*255).save(out/f);refs[k]=f
        layers.append(dict(name=name,operation=op,references=refs))
    add('trunk','union',[(0,0,1),(0,0,5),(-1,0,10),(-1.8,.7,16),(1,1,22),(2.5,-.5,28),(1,-2,34),(-1,-1,39)],[6.2,5.4,4.6,4.1,3.6,2.9,1.9,.8],.22)
    for i in range(7):
        a=i*math.tau/7+.17*math.sin(i);u=np.array([math.cos(a),math.sin(a),0]);v=np.array([-u[1],u[0],0])
        end=12+4*rng.random()
        pts=[u*2+[0,0,7],u*5+v*1.3+[0,0,4.8],u*9-v*1.2+[0,0,2.5],u*end+v*2+[0,0,.4]]
        add('root%02d'%i,'union',pts,[2.7,2.1,1.35,.45],.12)
        add('rib%02d'%i,'union',[u*4+[0,0,2],u*4.7+v*1.2+[0,0,8],u*3.7-v*.6+[0,0,15],u*3+v*1.3+[0,0,21]],[1.35,1.15,.85,.4])
    for i in range(8):
        a=i*2.39996+.3;u=np.array([math.cos(a),math.sin(a),0]);v=np.array([-u[1],u[0],0]);h=15+i*2.15;L=13+4*rng.random()
        b=np.array([0.,0.,h]);p1=b+u*5+v*1.5+[0,0,2];p2=b+u*(L*.65)-v*2+[0,0,4];p3=b+u*L+v*1.5+[0,0,8]
        add('branch%02d'%i,'union',[b,p1,p2,p3],[2.8-i*.13,2.15-i*.1,1.3,.55],.13)
        for j in range(2):
            start=p1*(1-(j+1)/3)+p2*((j+1)/3)
            direction=u*.65+v*(-1 if j==0 else 1)*.8
            add('fork%02d%d'%(i,j),'union',[start,start+direction*3+[0,0,2],start+direction*7+[0,0,6+j]],[1.15,.8,.32])
    add('hollow','subtract',[(0,-7,4),(0,-4,6),(.2,-2.8,8),(.5,-3,10)],[2.1,2.4,2.1,1.0])
    (out/'job.json').write_text(json.dumps(dict(schema=1,mode='layered_multi_view',layers=layers,triangle_budget=100000,sigma=.55),indent=2))
if __name__=='__main__':main()
