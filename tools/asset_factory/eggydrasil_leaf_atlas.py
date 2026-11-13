"""Original alpha foliage atlas: four botanical sprays, supersampled edges."""
import math,random,sys
from pathlib import Path
from PIL import Image,ImageDraw
out=Path(sys.argv[1]);out.mkdir(parents=True,exist_ok=True)
S=512;AA=2;atlas=Image.new("RGBA",(S*2,S*2))
def spray(seed,base):
    rng=random.Random(seed);im=Image.new("RGBA",(S*AA,S*AA));d=ImageDraw.Draw(im)
    def line(p,c,w):d.line([(round(x*AA),round(y*AA)) for x,y in p],fill=c,width=max(1,round(w*AA)),joint="curve")
    def poly(p,c):d.polygon([(round(x*AA),round(y*AA)) for x,y in p],fill=c)
    def shade(c,k):return tuple(max(0,min(255,int(v*k))) for v in c)+(255,)
    def leaf(x,y,angle,L,W,col):
        u=(math.cos(angle),math.sin(angle));v=(-u[1],u[0])
        def P(t,k):return (x+u[0]*L*t+v[0]*W*k,y+u[1]*L*t+v[1]*W*k)
        # pointed oval, irregular curvature, central vein and two tonal halves
        shape=[P(0,0),P(.13,.34),P(.38,.52),P(.66,.38),P(.85,.19),P(1,0),P(.83,-.21),P(.58,-.45),P(.32,-.48),P(.12,-.25)]
        poly(shape,shade(col,.75))
        poly([P(0,0),P(.15,.27),P(.38,.43),P(.65,.30),P(.89,.12),P(1,0),P(.52,.035)],shade(col,1.14))
        poly([P(0,0),P(.52,.035),P(1,0),P(.75,-.19),P(.52,-.35),P(.25,-.34)],shade(col,.90))
        line([P(.04,0),P(.44,.02),P(.87,0)],shade(col,1.35),1.4)
        for t in (.3,.53,.72):
            line([P(t,0),P(t+.1,.19)],shade(col,1.13),.8)
    # six fan branches, densely layered leaves, stem base common.
    origin=(256,439)
    for i,ang in enumerate([-.78,-1.08,-1.37,-1.72,-2.02,-2.35]):
        ang+=rng.uniform(-.08,.08);L=rng.uniform(190,300)
        u=(math.cos(ang),math.sin(ang));p=(origin[0]+u[0]*L,origin[1]+u[1]*L)
        line([origin,p],(86,106,37,255),3.3)
        for j in range(5):
            t=.23+j*.15;x=origin[0]+u[0]*L*t;y=origin[1]+u[1]*L*t
            for sign in [-1,1]:
                a=ang+sign*rng.uniform(.45,1.13);l=rng.uniform(53,88)*(1-.25*t)
                col=tuple(min(255,max(0,int(c*rng.uniform(.85,1.15)))) for c in base)
                leaf(x,y,a,l,l*rng.uniform(.47,.65),col)
        leaf(*p,ang,rng.uniform(38,57),32,base)
    return im.resize((S,S),Image.Resampling.LANCZOS)
for i,c in enumerate([(74,143,40),(100,168,48),(46,115,44),(130,178,57)]):
    atlas.paste(spray(830+i,c),((i%2)*S,(i//2)*S))
atlas.save(out/"leaves-atlas.png")
