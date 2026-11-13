"""Reference-guided contour geometry. Input outlines are annotated, not automatically inferred."""
import math

def contour_geometry(points, depth, *, origin=(0,0), scale=1.0, bevel_ratio=.84):
    """Convert image XY outline to upright XZ mesh; depth is inferred or supplied."""
    if len(points)<3 or depth<=0 or scale<=0 or not 0<bevel_ratio<1:
        raise ValueError("invalid contour parameters")
    if len(set(map(tuple,points)))!=len(points):
        raise ValueError("duplicate contour vertices")
    coords=[((origin[1]-y)*scale,(x-origin[0])*scale) for x,y in points]
    n=len(coords)
    area=sum(coords[i][0]*coords[(i+1)%n][1]-coords[(i+1)%n][0]*coords[i][1] for i in range(n))
    if abs(area)<1e-10: raise ValueError("degenerate contour")
    cx=sum(x for x,z in coords)/n; cz=sum(z for x,z in coords)/n
    v=[]; f=[]
    for yy,k in [(-depth*.5,bevel_ratio),(-depth*.32,1),(depth*.32,1),(depth*.5,bevel_ratio)]:
        v.extend([(cx+(x-cx)*k,yy,cz+(z-cz)*k) for x,z in coords])
    for j in range(3):
        for i in range(n):
            f.append((j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i))
    f.extend([tuple(reversed(range(n))),tuple(range(3*n,4*n))])
    return v,f
