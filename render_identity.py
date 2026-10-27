#!/usr/bin/env python3
"""Generate Krest marks, character, README banner and link previews from one JSON.
Run: uv run --with pillow --with fonttools python render_identity.py
The shared N1 projection, exposed-face rules and finite motion contract are kept.
"""
from pathlib import Path
from html import escape
import hashlib
import json
from PIL import Image, ImageDraw, ImageFont
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen

ROOT=Path(__file__).resolve().parent
ASSETS=ROOT/'site/assets'
SOURCE=ASSETS/'krest-identity.json'
I=json.loads(SOURCE.read_text())
P=I['palette']
SHA=hashlib.sha256(SOURCE.read_bytes()).hexdigest()
PALETTE=I['faces']


def projection(x,y,z):return ((x-y)*10,(x+y)*4.8-z*10)

def polygons():
 cells=I['model']['voxels'];occupied={tuple(v[:3]) for v in cells};out=[]
 for x,y,z,color in sorted(cells,key=lambda v:(sum(v[:3]),sum(v[:2]),v[2])):
  faces=[[(x,y,z+1),(x+1,y,z+1),(x+1,y+1,z+1),(x,y+1,z+1)],[(x,y+1,z+1),(x+1,y+1,z+1),(x+1,y+1,z),(x,y+1,z)],[(x+1,y,z+1),(x+1,y+1,z+1),(x+1,y+1,z),(x+1,y,z)]]
  for j,neighbor in enumerate([(x,y,z+1),(x,y+1,z),(x+1,y,z)]):
   if neighbor not in occupied:out.append(([projection(*p) for p in faces[j]],PALETTE[color][j]))
 return out


def voxel(x,y,w,h):
 polys=polygons();points=[p for poly,c in polys for p in poly];xmin=min(p[0] for p in points);ymin=min(p[1] for p in points);bw=max(p[0] for p in points)-xmin;bh=max(p[1] for p in points)-ymin;s=min(w/bw,h/bh);ox=x+(w-bw*s)/2;oy=y+(h-bh*s)/2
 return [([(ox+(px-xmin)*s,oy+(py-ymin)*s) for px,py in poly],c) for poly,c in polys]


def polygon_svg(points,color):return '<path fill="'+color+'" d="M'+'L'.join(f'{x:.2f} {y:.2f}' for x,y in points)+'Z"/>'


def mark_svg():
 f=I['frame'];sx,sy,sw,sh=I['signal'];paths=''.join('<path d="'+d+'"/>' for d in I['glyph'])
 return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48" role="img" aria-label="Krest · four directions"><rect x="{f["x"]}" y="{f["y"]}" width="{f["size"]}" height="{f["size"]}" rx="{f["radius"]}" fill="none" stroke="{P["ink"]}" stroke-width="{f["stroke"]}"/><g fill="none" stroke="{P["ink"]}" stroke-width="{f["stroke"]}" stroke-linecap="round">{paths}</g><rect x="{sx}" y="{sy}" width="{sw}" height="{sh}" rx=".5" fill="{P["red"]}"/></svg>'


class Canvas:
 def __init__(self,w,h,bg):
  self.w,self.h=w,h;self.im=Image.new('RGB',(w*2,h*2),bg);self.d=ImageDraw.Draw(self.im);self.parts=[f'<rect width="{w}" height="{h}" fill="{bg}"/>']
 def rect(self,x,y,w,h,color):
  self.d.rectangle((x*2,y*2,(x+w)*2,(y+h)*2),fill=color);self.parts.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{color}"/>')
 def text(self,x,y,text,size=24,color=None,bold=False):
  color=color or P['ink'];path=ROOT/'native/assets'/('plex-mono-600.ttf' if bold else 'plex-mono-400.ttf');font=ImageFont.truetype(str(path),size*2);self.d.text((x*2,y*2),text,font=font,fill=color,anchor='lt')
  tt=TTFont(path);glyphs=tt.getGlyphSet();cmap=tt.getBestCmap();scale=size/tt['head'].unitsPerEm;cap=tt['OS/2'].sCapHeight;offset=0;pieces=[]
  for ch in text:
   name=cmap.get(ord(ch),'.notdef');pen=SVGPathPen(glyphs);glyphs[name].draw(pen);pieces.append(f'<path transform="translate({offset} 0)" d="{pen.getCommands()}"/>');offset+=tt['hmtx'][name][0]
  self.parts.append(f'<g fill="{color}" aria-label="{escape(text,quote=True)}" transform="translate({x} {y+cap*scale:.2f}) scale({scale} {-scale})">'+''.join(pieces)+'</g>')
 def character(self,x,y,w,h):
  for points,c in voxel(x,y,w,h):self.d.polygon([(px*2,py*2) for px,py in points],fill=c);self.parts.append(polygon_svg(points,c))
 def mark(self,x,y,size=48):
  inner=mark_svg().split('>',1)[1].rsplit('</svg>',1)[0];self.parts.append(f'<g transform="translate({x} {y}) scale({size/48})">'+inner+'</g>')
  from fontTools.svgLib.path import parse_path
  from fontTools.pens.recordingPen import RecordingPen
  d=self.d;s=size/48*2;f=I['frame'];left,top=f['x'],f['y'];right=left+f['size'];bottom=top+f['size']
  d.rounded_rectangle((x*2+left*s,y*2+top*s,x*2+right*s,y*2+bottom*s),radius=f['radius']*s,outline=P['ink'],width=max(1,round(f['stroke']*s)))
  for path in I['glyph']:
   pen=RecordingPen();parse_path(path,pen);points=[(x*2+pt[0]*s,y*2+pt[1]*s) for op,args in pen.value for pt in args if op in ('moveTo','lineTo')]
   d.line(points,fill=P['ink'],width=max(1,round(f['stroke']*s)))
  sx,sy,sw,sh=I['signal'];d.rectangle((x*2+sx*s,y*2+sy*s,x*2+(sx+sw)*s,y*2+(sy+sh)*s),fill=P['red'])

 def aim(self,x,y,size=96):
  # Preserve the complete approved AIM silhouette, including its right stem.
  logo=Image.open(ASSETS/'aim-logo-light.png').convert('RGBA')
  logo.thumbnail((size*2,size*2),Image.Resampling.LANCZOS)
  self.im.paste(logo,(x*2,y*2),logo)

 def save(self,path,png_only=False):
  path=Path(path);self.im.resize((self.w,self.h),Image.Resampling.LANCZOS).save(path.with_suffix('.png'),optimize=True)
  if png_only:return
  path.with_suffix('.svg').write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="{self.w}" height="{self.h}" viewBox="0 0 {self.w} {self.h}" role="img"><title>Krest · AI Mindset</title><!-- Generated from krest-identity.json SHA-256 {SHA} -->'+''.join(self.parts)+'</svg>')


def render():
 assert len(I['model']['voxels'])<=200
 assert len({tuple(v[:3]) for v in I['model']['voxels']})==len(I['model']['voxels'])
 assert all(0<=n<12 for v in I['model']['voxels'] for n in v[:3])
 assert sum(v[3]=='red' for v in I['model']['voxels'])==4
 (ASSETS/'krest-mark.svg').write_text(mark_svg()+'\n');(ROOT/'site/favicon.svg').write_text(mark_svg()+'\n')
 (ASSETS/'voxel-krest.svg').write_text('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 320 360" width="320" height="360" role="img" aria-label="Krest · four directions"><title>Krest</title><!-- Generated from krest-identity.json -->'+''.join(polygon_svg(p,c) for p,c in voxel(20,12,280,328))+'</svg>\n')
 icon=Canvas(180,180,P['white']);icon.mark(0,0,180);icon.im.resize((180,180),Image.Resampling.LANCZOS).save(ROOT/'site/apple-touch-icon.png')
 banner=Canvas(1200,400,P['wash']);banner.text(64,40,'AI MINDSET / SMALL TOOLS',16,P['muted']);banner.text(58,88,'KREST',88,P['red'],True);banner.text(64,204,'your day, in four directions.',27);banner.text(64,256,'demo · Mac · your own agent',19,P['muted']);banner.rect(64,316,646,1,P['line']);banner.text(64,342,'apps.aimindset.org/krest',19,bold=True);banner.character(838,54,292,294);banner.save(ASSETS/'readme-banner')
 for lang,kind,credit,labels in [
  ('en','toxic cross','a model by Seva Ustinov',('obligations','resources','past','future')),
  ('ru','токсичный крест','модель Севы Устинова',('обязательства','ресурсы','прошлое','будущее')),
 ]:
  c=Canvas(1200,630,P['wash'])
  c.text(64,44,'AI Mindset',32,bold=True)
  c.text(58,146,'Krest',100,P['red'],True)
  c.text(64,272,kind,32)
  c.text(64,372,credit,22,P['muted'])
  c.rect(64,482,590,1,P['line'])
  c.text(64,526,'apps.aimindset.org/krest',20,bold=True)
  c.character(780,165,300,300)
  top,bottom,left,right=labels
  c.text(930-len(top)*6,114,top,20)
  c.text(930-len(bottom)*6,493,bottom,20)
  c.text(756-len(left)*12,312,left,20)
  c.text(1100,312,right,20)
  c.aim(1060,524,96)
  c.save(ROOT/'site'/f'og-krest-{lang}-20261027',png_only=True)
 for name,label in [('demo','try the demo'),('mac','download for Mac'),('configure','configure'),('agent','set up with your agent')]:
  width=round(len(label)*8.4+30);c=Canvas(width,38,P['white']);c.d.rounded_rectangle((1,1,width*2-2,74),radius=4,outline=P['ink'],width=2);c.parts.append(f'<rect x=".5" y=".5" width="{width-1}" height="37" rx="2" fill="none" stroke="{P["ink"]}"/>');c.text(15,13,label,14);c.save(ROOT/'docs'/('readme-'+name))
 print('Rendered identity, banner and previews:',I['model']['count'],'voxels')

if __name__=='__main__':render()
