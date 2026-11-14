from PIL import Image,ImageDraw,ImageFont
from pathlib import Path
import sys
p=Path(sys.argv[1]);out=Image.new("RGB",(1500,1110),(25,31,41));d=ImageDraw.Draw(out)
font="/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf";bold="/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
d.text((36,22),"BLACK ISLANDS  /  S08",font=ImageFont.truetype(bold,36),fill=(240,245,250))
d.text((38,68),"Approved runtime models | source geometry and real albedos",font=ImageFont.truetype(font,20),fill=(165,181,199))
def panel(name,caption,x,y,w,h):
    d.rounded_rectangle((x,y,x+w,y+h),radius=18,fill=(43,53,67))
    im=Image.open(p/(name+".png")).convert("RGBA");im.thumbnail((w-24,h-62),Image.Resampling.LANCZOS)
    out.paste(im,(x+(w-im.width)//2,y+12+(h-62-im.height)//2),im)
    d.text((x+20,y+h-42),caption,font=ImageFont.truetype(bold,21),fill=(231,239,245))
panel("stone","STONE / 80 tris",36,110,460,350)
panel("stick","STICK / 120 tris",520,110,460,350)
panel("log","LOG / 636 tris",1004,110,460,350)
panel("eggydrasil","EGGYDRASIL V8 / neutral",36,480,700,580)
panel("eggydrasil-tint","EGGYDRASIL V8 / pink + purple",764,480,700,580)
d.text((36,1078),"Blender asset preview - not a Roblox client screenshot",font=ImageFont.truetype(font,18),fill=(165,181,199))
out.save(p/"contact-sheet.png")
