#!/usr/bin/env python3
"""Render a 1200x630 link preview from authentic voxel polygons; requires Pillow."""
from pathlib import Path
import re
import xml.etree.ElementTree as ET
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent
SCALE = 3
image = Image.new('RGB', (1200*SCALE, 630*SCALE), '#ffffff')
draw = ImageDraw.Draw(image)

def font(size, bold=False):
    return ImageFont.truetype(str(ROOT/'native/assets'/('plex-mono-600.ttf' if bold else 'plex-mono-400.ttf')), size*SCALE)

def text(x,y,value,size=24,fill='#202124',bold=False):
    draw.text((x*SCALE,y*SCALE),value,font=font(size,bold),fill=fill)

def voxel(path,x,y,width,height):
    root=ET.parse(path).getroot()
    vx,vy,vw,vh=map(float,root.attrib['viewBox'].split())
    factor=min(width/vw,height/vh)
    ox=x+(width-vw*factor)/2;oy=y+(height-vh*factor)/2
    def paint(node,fill='#202124'):
        colour=node.attrib.get('fill',fill)
        if node.tag.endswith('path'):
            data=node.attrib['d']
            if re.search(r'[CQAHSTcqahst]',data):raise ValueError('Expected the original polygon-only voxel export')
            nums=list(map(float,re.findall(r'-?\d+(?:\.\d+)?',data)))
            points=[((ox+(nums[i]-vx)*factor)*SCALE,(oy+(nums[i+1]-vy)*factor)*SCALE) for i in range(0,len(nums),2)]
            draw.polygon(points,fill=colour)
        for child in node:paint(child,colour)
    paint(root)

text(64,44,'AI Mindset',36,bold=True)
draw.rectangle((64*SCALE,112*SCALE,184*SCALE,116*SCALE),fill='#db303d')
text(60,146,'Krest',94,bold=True)
text(64,270,'your day, in four directions',27,fill='#6b6e75')
text(64,354,'Demo · Mac · configure · agent',25)
text(64,398,'Your own field, on your data',25)
draw.line((64*SCALE,494*SCALE,662*SCALE,494*SCALE),fill='#e8e9ed',width=2*SCALE)
text(64,520,'A setup kit for Claude Code / Codex',22,fill='#6b6e75')
text(64,558,'Experimental · inspect the method',18,fill='#6b6e75')
voxel(ROOT/'site/assets/voxel-krest.svg',752,146,326,392)
voxel(ROOT/'site/assets/voxel-family.svg',1092,486,64,88)
output=ROOT/'site/social-package-20261027.png'
image.resize((1200,630),Image.Resampling.LANCZOS).save(output,optimize=True)
print(output)
