"""Original disconnected leaf cards: no stems or connected sprays."""
import math,random,sys
from pathlib import Path
from PIL import Image,ImageDraw
out=Path(sys.argv[1]);out.mkdir(parents=True,exist_ok=True)
S=512;AA=3;atlas=Image.new("RGBA",(1024,1024))
def tile(seed,base):
    rng=random.Random(seed);im=Image.new("RGBA",(S*AA,S*AA));d=ImageDraw.Draw(im)
    def poly(points,c):d.polygon([(round(x*AA),round(y*AA)) for x,y in points],fill=c)
    def line(points,c,w):d.line([(round(x*AA),round(y*AA)) for x,y in points],fill=c,width=round(w*AA),joint="curve")
    def shade(c,k):return tuple(max(0,min(255,round(v*k))) for v in c)+(255,)
    for row in range(5):
        for col in range(5):
            if rng.random()<.12:continue
            cx=56+col*100+rng.uniform(-8,8);cy=56+row*100+rng.uniform(-8,8)
            a=rng.uniform(0,math.tau);L=rng.uniform(59,84);W=L*rng.uniform(.43,.65)
            u=(math.cos(a),math.sin(a));v=(-u[1],u[0]);bend=rng.uniform(-.12,.12)
            c=tuple(round(x*rng.uniform(.84,1.15)) for x in base)
            def P(t,k):
                k+=bend*math.sin(math.pi*t)
                return (cx+u[0]*L*(t-.5)+v[0]*W*k,cy+u[1]*L*(t-.5)+v[1]*W*k)
            def w(t):return .50*math.sin(math.pi*t)**.88*(1+.16*math.sin(5*t))
            ts=[i/24 for i in range(25)]
            # Smooth tapered leaf with a folded center ridge and painterly bands.
            poly([P(t,w(t)) for t in ts]+[P(t,-w(t)*.91) for t in reversed(ts)],shade(c,.72))
            for side in (-1,1):
                for j in range(7,0,-1):
                    frac=j/7
                    poly([P(t,side*w(t)*frac*(.91 if side<0 else 1)) for t in ts]+[P(t,0) for t in reversed(ts)],shade(c,(.77 if side<0 else 1.0)+(.20 if side<0 else .24)*(1-frac)))
            line([P(t,0) for t in ts[2:-2]],shade(c,1.25),1.0)
            for t in (.25,.43,.61,.74):
                for side in (-1,1):
                    line([P(t,0),P(t+.10,side*w(t+.1)*.65)],shade(c,1.04 if side>0 else .89),.65)
    return im.resize((S,S),Image.Resampling.LANCZOS)
for i,c in enumerate([(75,142,42),(108,165,49),(52,115,45),(134,177,65)]):
    atlas.paste(tile(830+i,c),((i%2)*S,(i//2)*S))
atlas.save(out/"leaves-atlas.png")
