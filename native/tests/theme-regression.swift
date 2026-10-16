import AppKit
let app=NSApplication.shared
app.setActivationPolicy(.prohibited)
UI.registerFonts()
let original=app.appearance
defer {app.appearance=original}
let fixture=try Data(contentsOf:URL(fileURLWithPath:"assets/демо.json"))
let day=День.разобрать(fixture,живой:true)!
AIMThemePolicy.apply(.light)
let panel=AIMThemePolicy.withAppearance(.light) {ПанельView(frame:NSRect(x:0,y:0,width:520,height:690))}
let window=NSWindow(contentRect:panel.frame,styleMask:.borderless,backing:.buffered,defer:false)
window.contentView=panel
panel.показать(day)
let r=BalanceRecord.make(day,sourceID:"theme-fixture",origin:"test")!
panel.history([r],status:"Fictional observation")
let now=Date(),start=Calendar.current.startOfDay(for:now)
let event=CalendarMoment(id:"fictional",title:"Fictional current entry",start:now.addingTimeInterval(-300),end:now.addingTimeInterval(900),allDay:false,declined:false,url:nil,source:"test")
panel.calendar(CalendarFrame(events:[event],source:"fictional",fetched:now,start:start,end:start.addingTimeInterval(86400),issue:nil))
func rgb(_ color:NSColor)->[Double] {let c=color.usingColorSpace(.sRGB)!;return [Double(c.redComponent),Double(c.greenComponent),Double(c.blueComponent)]}
func resolved(_ color:NSColor,_ appearance:NSAppearance)->[Double] {var v:[Double]=[];appearance.performAsCurrentDrawingAppearance{v=rgb(color)};return v}
func same(_ a:[Double],_ b:[Double])->Bool {zip(a,b).allSatisfy{abs($0-$1)<0.025}}
func descendants(_ v:NSView)->[NSView] {[v]+v.subviews.flatMap(descendants)}
var checks=0
for view in ["now","day","history","settings"] {
 panel.select(view)
 for mode:AIMThemePolicy.Mode in [.light,.dark,.light] {
  let target=AIMThemePolicy.appearance(mode)!,opposite=AIMThemePolicy.appearance(mode == .light ? .dark:.light)!
  opposite.performAsCurrentDrawingAppearance {
   AIMThemePolicy.apply(mode);panel.themeChanged(mode);panel.layoutSubtreeIfNeeded()
   let expected=resolved(UI.white,target)
   assert(same(rgb(NSColor(cgColor:panel.layer!.backgroundColor!)!),expected),"retained panel canvas inherited old appearance")
   let palette=[UI.white,UI.gray200,UI.ink,UI.red,AIMAppShellStyle.plate].map{resolved($0,target)}
   for v in descendants(panel) {
    if let cg=v.layer?.backgroundColor {assert(palette.contains{same(rgb(NSColor(cgColor:cg)!),$0)},"a retained layer has stale appearance")}
    if let label=v as? NSTextField,let color=label.textColor,!label.stringValue.isEmpty {
     assert(same(resolved(color,v.effectiveAppearance),resolved(color,target)),"text appearance mismatches panel")
    }
   }
   let canvas=expected,ink=resolved(UI.ink,target),muted=resolved(UI.gray600,target)
   func lum(_ rgb:[Double])->Double {let c=rgb.map{$0<=0.04045 ? $0/12.92:pow(($0+0.055)/1.055,2.4)};return c[0]*0.2126+c[1]*0.7152+c[2]*0.0722}
   for text in [ink,muted] {let a=lum(canvas),b=lum(text);assert((max(a,b)+0.05)/(min(a,b)+0.05)>=4.5,"text contrast below 4.5")}
   assert(panel.navigation.current==view && panel.frame.size==NSSize(width:520,height:690))
   let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:520,pixelsHigh:690,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
   let context=NSGraphicsContext(bitmapImageRep:bitmap)!
   panel.layer!.render(in:context.cgContext)
   // Rasterize the retained layer, including its immutable canvas CGColor.
   assert(same(rgb(bitmap.colorAt(x:2,y:2)!),expected),"retained layer pixel canvas mismatch")
   checks+=1
  }
 }
}
print("PASS theme regression: \(checks) retained-panel renders, opposite drawing context, canvas pixels, layer palette, text/control appearance, contrast, History entry, Day and Settings; no defaults/history writes")
