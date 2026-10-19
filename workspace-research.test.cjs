const assert=require('node:assert/strict');
const fs=require('node:fs');
const {JSDOM}=require(process.env.KREST_JSDOM||'jsdom');
const {normalize,statusFor,recordBalance,reconcileRecordState}=require('./site/assets/workspace-v2.js');
const fixture=JSON.parse(fs.readFileSync('site/example-v2.json','utf8'));
const script=fs.readFileSync('site/assets/workspace-v2.js','utf8');
const stylesheet=fs.readFileSync('site/assets/workspace-v2.css','utf8');
const tick=()=>new Promise(resolve=>setTimeout(resolve,15));
async function mount({raw=fixture,demo=true,hash='',reviews=[]}={}){
 const dom=new JSDOM(`<style>${stylesheet}</style><div id="krest-workspace" data-mode="${demo?'demo':'private'}" data-context="fixture.json"></div>`,{url:'http://localhost/'+hash,runScripts:'outside-only'});
 const w=dom.window,calls=[];
 w.HTMLDialogElement.prototype.showModal=function(){this.setAttribute('open','');};
 w.HTMLDialogElement.prototype.close=function(){this.removeAttribute('open');};
 w.fetch=async(url,options)=>{calls.push([url,options]);return {ok:true,json:async()=>url==='/check-ins'?reviews:url==='/check-in'?{ok:true,entry:{...JSON.parse(options.body),feeling:2,recorded:'2026-10-19T12:34:56Z'},revision:'canonical'}:raw};};
 w.eval(script);await tick();
 const q=s=>{const el=w.document.querySelector(s);assert(el,s+' exists');return el;};
 const click=s=>q(s).dispatchEvent(new w.MouseEvent('click',{bubbles:true}));
 const change=(s,value)=>{q(s).value=value;q(s).dispatchEvent(new w.Event(s==='input'?'input':'change',{bubbles:true}));};
 return {dom,w,calls,q,click,change};
}
(async()=>{
 const normalized=normalize(fixture,new Date('2026-10-19T12:00:00Z'));
 assert.equal(normalized.records.length,10);
 assert.equal(normalized.records[0].hours,12,'fixture т_ч normalizes');
 assert.equal(normalize({'лучи':{'прошлое':{'элементы':[{'т':'unknown'},{'т':'legacy','ч':-72}]}}}).records[0].hours,null);
 assert.equal(normalize({'лучи':{'прошлое':{'элементы':[{'т':'legacy','ч':-72}]}}}).records[0].hours,-72);
 assert.equal(statusFor({статус:'live',expiresAt:'2026-10-19T12:00Z'},new Date('2026-10-19T12:00Z')),'expired');
 const before=JSON.stringify(normalized.records),target=new Set([normalized.records[0].key]);
 assert.equal(recordBalance(normalized.records,.5,target).sums['обязательства'],7);
 const observed=recordBalance(normalized.records),all=new Set(normalized.records.map(r=>r.key));
 const lighter=recordBalance(normalized.records,.25,all);
 assert(Math.abs(lighter.x-observed.x*.25)<1e-10,'preview keeps observed normalization');
 assert(Math.abs(lighter.y-observed.y*.25)<1e-10,'all lighter weights visibly approach the centre');
 assert.equal(JSON.stringify(normalized.records),before,'preview never mutates observations');
 // A UI index must never become a different source record after a live snapshot refresh.
 const record=(key,id,source='shared',adapter='calendar',kind='adapter')=>({key,id,source,evidence:{adapter,kind}});
 const prior=[record('обязательства:0','A'),record('обязательства:1','B')];
 const state={selectedRecord:prior[0].key,recordTrigger:{key:prior[0].key,row:true},previewTargets:new Set(prior.map(r=>r.key))};
 let reconciled=reconcileRecordState(prior,[record('обязательства:0','B'),record('обязательства:1','A')],state);
 assert.equal(reconciled.selectedRecord,'обязательства:1');assert.equal(reconciled.recordTrigger.key,'обязательства:1');
 assert.deepEqual([...reconciled.previewTargets],['обязательства:1','обязательства:0']);
 reconciled=reconcileRecordState(prior,[record('ресурсы:0','A'),record('обязательства:0','B')],state);
 assert.equal(reconciled.selectedRecord,'ресурсы:0','unique identity may move between arms');
 reconciled=reconcileRecordState(prior,[record('обязательства:0','B')],state);
 assert.equal(reconciled.selectedRecord,'','removed record closes instead of selecting replacement at same index');
 assert.equal(reconciled.recordTrigger,null);assert.deepEqual([...reconciled.previewTargets],['обязательства:0'],'remaining preview follows B, while A is dropped');
 const adapters=[record('обязательства:0','same','shared','calendar'),record('обязательства:1','same','shared','tasks')];
 reconciled=reconcileRecordState(adapters,[record('обязательства:0','same','shared','tasks'),record('обязательства:1','same','shared','calendar')],{...state,previewTargets:new Set(['обязательства:0'])});
 assert.equal(reconciled.selectedRecord,'обязательства:1','same ID from different adapters stays distinct');assert.deepEqual([...reconciled.previewTargets],['обязательства:1']);
 for(const next of [
  [record('обязательства:0','A'),record('ресурсы:0','A')],
  [record('обязательства:0','A','different-source')],
  [record('обязательства:0','A','shared','calendar','manual')],
  [record('обязательства:0',undefined)]
 ]){reconciled=reconcileRecordState(prior,next,{...state,previewTargets:new Set(['обязательства:0'])});assert.equal(reconciled.selectedRecord,'','ambiguous, changed or missing source identity is discarded');assert.equal(reconciled.previewTargets.size,0);}
 reconciled=reconcileRecordState([record('обязательства:0','A'),record('ресурсы:0','A')],[record('обязательства:0','A')],{...state,previewTargets:new Set(['обязательства:0'])});
 assert.equal(reconciled.selectedRecord,'','collision in the previous snapshot cannot be resolved by guessing');assert.equal(reconciled.previewTargets.size,0);
 assert.equal(state.selectedRecord,'обязательства:0');assert.deepEqual([...state.previewTargets],prior.map(r=>r.key),'reconciliation leaves previous state unchanged');
 const liveInitial={...fixture,'лучи':{'обязательства':{элементы:[{id:'live-A',т:'Live original A',вес:8,источник:'shared',evidence:{kind:'adapter',adapter:'calendar'}},{id:'live-B',т:'Live original B',вес:3,источник:'shared',evidence:{kind:'adapter',adapter:'calendar'}}]}}};
 const live=await mount({raw:liveInitial});
 {
  const {w,q,click}=live;
  const refresh=async raw=>{w.fetch=async()=>({ok:true,json:async()=>raw});Object.defineProperty(w.document,'hidden',{value:false,configurable:true});w.document.dispatchEvent(new w.Event('visibilitychange'));await tick();};
  const a=liveInitial['лучи']['обязательства'].элементы[0],b=liveInitial['лучи']['обязательства'].элементы[1];
  click('.record-row[data-record="обязательства:0"]');click('[data-preview-record]');
  await refresh({...liveInitial,'лучи':{'обязательства':{элементы:[b,{...a,т:'Live A after reorder'}]}}});
  assert.equal(q('.research-detail h2').textContent,'Live A after reorder','open drawer follows identity through refresh');
  assert.equal(q('[data-preview-record]').dataset.previewRecord,'обязательства:1');assert.equal(q('[data-preview-record]').getAttribute('aria-pressed'),'true','preview follows same source');
  q('#detail-preview-multiplier').dispatchEvent(new w.KeyboardEvent('keydown',{key:'Escape',bubbles:true}));
  assert.equal(w.document.activeElement.dataset.record,'обязательства:1','focus return trigger follows reordered identity');
  click('.record-row[data-record="обязательства:1"]');
  await refresh({...liveInitial,'лучи':{'обязательства':{элементы:[b]},'ресурсы':{элементы:[a]}}});
  assert.equal(q('[data-preview-record]').dataset.previewRecord,'ресурсы:0','live state follows unique source to a new arm');
  await refresh({...liveInitial,'лучи':{'ресурсы':{элементы:[b]}}});
  assert(!w.document.querySelector('.research-detail'),'removal closes drawer despite occupied old index');
  assert(!w.document.querySelector('.preview-dot'),'removed source leaves preview');
  assert(!q('.app').inert);assert.equal(w.document.activeElement.dataset.layout,'cross','closing stale drawer restores usable focus');
  click('.record-row');click('[data-preview-record]');
  await refresh({...liveInitial,'лучи':{'обязательства':{элементы:[b]},'ресурсы':{элементы:[{...b}]}}});
  assert(!w.document.querySelector('.research-detail'),'canonical collision closes live drawer');assert(!w.document.querySelector('.preview-dot'));
  w.close();
 }
 let compact=await mount();
 {
  const {w,q,click,calls}=compact,original=JSON.stringify(fixture);
  const key=(target,key,shiftKey=false)=>target.dispatchEvent(new w.KeyboardEvent('keydown',{key,shiftKey,bubbles:true,cancelable:true}));
  assert(!w.document.querySelector('.research-detail'),'initial board has no empty detail sidebar or modal');
  assert(q('#research-filters').hidden,'optional filters start collapsed');
  assert.equal(q('[data-action="toggle-filters"]').getAttribute('aria-expanded'),'false');
  assert(!q('.instrument-guide').open,'long reading guide starts collapsed');
  assert(!q('.preview-options').open,'preview settings start collapsed');
  assert(!q('.source-inventory').open,'source inventory starts collapsed but retains receipts');
  click('[data-action="toggle-filters"]');
  assert(!q('#research-filters').hidden);
  q('#research-scope').value='недельное';q('#research-scope').dispatchEvent(new w.Event('change',{bubbles:true}));
  assert(!q('#research-filters').hidden,'filter panel stays open while editing');
  click('[data-action="clear-filters"]');click('[data-action="toggle-filters"]');
  for(const arm of ['обязательства','ресурсы','прошлое','будущее']){
   const label=q('.cross-direction[data-focus-arm="'+arm+'"]');
   assert.equal(label.getAttribute('role'),'button');assert.equal(label.getAttribute('tabindex'),'0');
   assert.match(label.getAttribute('aria-label'),/records; weight/);
   label.focus();key(label,'Enter');
   assert(q('.focused-arm'));
   assert.equal(w.document.activeElement,q('.focused-arm'),'arm activation moves focus to its content');
   const expected=normalize(fixture).records.filter(r=>r.arm===arm);
   assert.equal(w.document.querySelectorAll('.record-row').length,expected.length,'focused view shows only its complete arm');
   for(const record of expected){const row=q('.record-row[data-record="'+record.key+'"]');assert(row.textContent.includes(record.title),'full title remains available');assert.match(row.textContent,/weight/);assert.match(row.textContent,/ago|ahead|now|unknown/);}
   assert.equal(w.document.querySelectorAll('.timeline-record').length,expected.length);
   click('[data-action="all-arms"]');
   assert.equal(w.document.activeElement,q('.arm-heading-link[data-focus-arm="'+arm+'"]'),'back returns focus to direction heading');
  }
  assert.equal(w.document.querySelectorAll('.arm-quick-nav button').length,4,'four readable controls accompany the scaled cross');
  for(const arm of ['обязательства','ресурсы','прошлое','будущее']){
   const control=q('.arm-quick-nav [data-focus-arm="'+arm+'"]');
   assert(Number.parseFloat(w.getComputedStyle(control).minHeight)>=44,'direction control keeps a full touch target');
   assert.match(control.textContent,/records · weight/,'control exposes its record count and observed weight');
   click('.arm-quick-nav [data-focus-arm="'+arm+'"]');
   assert(q('.focused-arm'));assert.equal(q('#research-arm').value,arm,'quick control drills into its own arm');
   click('[data-action="all-arms"]');
  }
  click('.arm-heading-link[data-focus-arm="обязательства"]');assert(q('.focused-arm'));
  const selectedKey=q('.record-row').dataset.record;
  q('.record-row').focus();click('.record-row');
  assert.equal(q('.research-detail').getAttribute('aria-modal'),'true');
  assert.equal(q('.research-detail').getAttribute('aria-labelledby'),q('.research-detail h2').id);
  assert.equal(q('.app').inert,true,'board becomes inert behind drawer');
  assert(q('html').classList.contains('record-open'),'document scrolling is locked while inspecting');
  assert.equal(w.document.activeElement,q('[data-action="clear-record"]'));
  const close=q('[data-action="clear-record"]'),last=q('[data-action="record-source"]');
  close.focus();key(close,'Tab',true);assert.equal(w.document.activeElement,last,'Shift+Tab wraps inside drawer');
  key(last,'Tab');assert.equal(w.document.activeElement,close,'Tab wraps inside drawer');
  q('.research-detail').scrollTop=700;
  click('[data-preview-record]');assert.match(q('.research-detail').textContent,/arbitrary ×0.25/);
  assert.equal(q('.research-detail').scrollTop,700,'preview rerender preserves inspection scroll position');
  const multiplier=q('#detail-preview-multiplier');multiplier.value='.55';multiplier.dispatchEvent(new w.Event('change',{bubbles:true}));
  assert.match(q('.research-detail').textContent,/arbitrary ×0.55/);
  assert.equal(w.document.activeElement.id,'detail-preview-multiplier','drawer rerender preserves input focus');
  key(q('#detail-preview-multiplier'),'Escape');
  assert(!w.document.querySelector('.research-detail'),'Escape closes drawer from an input');
  assert(!q('.app').inert);assert(!q('html').classList.contains('record-open'));
  assert.equal(w.document.activeElement.dataset.record,selectedKey,'Escape returns focus to originating record');
  assert(q('.focused-arm'),'closing record preserves focused direction');
  click('.record-row');click('[data-dismiss-record]');assert(!w.document.querySelector('.research-detail'),'backdrop closes drawer');
  click('.record-row');click('[data-action="clear-record"]');assert.equal(w.document.activeElement.dataset.record,selectedKey);
  key(q('.record-row'),'Escape');assert(!w.document.querySelector('.focused-arm'),'next Escape returns to cross');
  assert.equal(w.document.activeElement.dataset.focusArm,'обязательства');
  assert.equal(JSON.stringify(fixture),original,'drawer, arm navigation and previews leave source records unchanged');
  assert(calls.every(([url])=>url==='fixture.json'),'inspection never submits a journal entry');
  assert.equal(w.getComputedStyle(q('.research-body')).display,'block','canvas never reserves a sidebar column');
  for(const selector of ['.research-cross','.research-time']){
   if(selector==='.research-time')click('[data-layout="time"]');
   assert.equal(parseFloat(w.getComputedStyle(q(selector)).minWidth),0,'SVG can shrink to its container');
   assert.equal(w.getComputedStyle(q(selector)).width,'100%');
  }
  assert.notEqual(w.getComputedStyle(q('.cross-stage')).overflow,'auto','canvas does not create horizontal scrolling');
  click('[data-layout="cross"]');
  for(const width of [390,1280]){
   const contentWidth=width-(width===390?32:72)-(width===390?22:46);
   for(const target of w.document.querySelectorAll('.cross-direction rect')){
    const x=Number(target.getAttribute('x')),right=x+Number(target.getAttribute('width'));
    assert(x>=0&&right<=1040,`direction target fits SVG at ${width}px`);
    assert(right/1040*contentWidth<=contentWidth,'scaled hit region remains inside available canvas');
   }
  }
  click('.research-block');key(q('[data-action="clear-record"]'),'Escape');
  assert(w.document.activeElement.classList.contains('research-block'),'SVG block also receives restored focus');
  click('[data-tab="method"]');assert.match(q('#workspace-main').textContent,/Saving records both −2…\+2 ratings; each starts at 0/,'method describes actual saved rating defaults');
  w.close();
 }
 let {w,calls,q,click}=await mount();
 assert.equal(q('[role="tab"][aria-selected=true]').dataset.tab,'research');
 assert.equal(w.document.querySelectorAll('.record-row').length,10,'every fixture record is available');
 assert.match(q('.scope-receipt').textContent,/10 of 10/);
 assert.match(q('.demo-line').textContent,/FICTIONAL DAY/);
 assert(q('.demo-line a').href.endsWith('/build.html'));
 assert(!w.document.querySelector('.classic-link'),'public demo has no private classic link');
 assert(calls.every(([url])=>url==='fixture.json'),'public fixture never requests personal endpoints');
 click('.record-row');
 assert.match(q('.research-detail').textContent,/Manually declared context/);
 const targetKey=q('.record-row').dataset.record;
 click('[data-preview-record]');
 assert.match(q('.preview-label').textContent,/ILLUSTRATIVE PREVIEW/);
 q('#preview-multiplier').value='.6';q('#preview-multiplier').dispatchEvent(new w.Event('change',{bubbles:true}));
 assert.match(q('.research-detail').textContent,/arbitrary ×0.60/);
 assert(q('.preview-dot'));
 assert.equal(q('.record-row').dataset.record,targetKey);
 click('[data-action="preview"]');assert(!w.document.querySelector('.preview-dot'));
 q('#research-search').value='uninterrupted';q('#research-search').dispatchEvent(new w.Event('input',{bubbles:true}));
 assert.equal(w.document.querySelectorAll('.record-row').length,1);
 assert.match(q('.scope-receipt').textContent,/1 of 10/);
 assert.equal(w.document.activeElement.id,'research-search','typing keeps focus');
 click('[data-action="clear-filters"]');
 click('[data-layout="time"]');assert(q('.research-time'));
 click('[data-layout="process"]');assert.equal(w.document.querySelectorAll('.process-view section').length,4);
 click('[data-layout="cross"]');
 q('.research-block').dispatchEvent(new w.KeyboardEvent('keydown',{key:'Enter',bubbles:true}));
 assert.match(q('.research-detail').textContent,/Share the first draft/);
 click('[data-tab="today"]');assert.equal(w.location.hash,'#today');
 assert.equal(w.document.querySelectorAll('[data-event]').length,4,'compact day remains intact');
 click('[data-event="fictional-review"]');
 click('[data-rating="feeling"][data-value="1"]');click('[data-rating="energy"][data-value="-1"]');
 q('#reframe-note').value='Fictional next step';click('[data-action="save"]');await tick();
 assert(!q('dialog').open);assert.match(q('#workspace-main').textContent,/pleasant · energy lower/);
 const stored=JSON.parse(w.localStorage.getItem('krest.demo.checkins.v2'));
 assert.equal(stored[0].feeling,1);assert(!JSON.stringify(stored).includes('Fictional design review'));
 click('[data-tab="research"]');assert.match(q('.research-checkins').textContent,/1 recorded/);
 click('[data-tab="sources"]');assert.match(q('#workspace-main').textContent,/Know what the picture/);
 click('[data-tab="method"]');assert.match(q('#workspace-main').textContent,/arbitrary multiplier/);
 q('[data-tab="method"]').dispatchEvent(new w.KeyboardEvent('keydown',{key:'Home',bubbles:true}));
 assert.equal(q('[role="tab"][aria-selected=true]').dataset.tab,'today');
 assert.equal(w.document.activeElement.id,'view-today');
 w.document.body.dispatchEvent(new w.KeyboardEvent('keydown',{key:'r',bubbles:true}));
 assert.equal(q('[role="tab"][aria-selected=true]').dataset.tab,'research');
 w.close();
 const raw={...fixture,fictional:false,'лучи':{'обязательства':{'сумма':7,'элементы':[
  {id:'adapter',т:'<img src=x onerror=boom>',вес:4,ч:24,источник:'legacy-alias',факт:'<script>boom</script>',evidence:{kind:'adapter',adapter:'calendar',observedAt:'2026-01-01T12:00:00Z',weight:{base:2,scale:2,decay:1,override:null}}},
  {id:'manual',т:'Old call annotation',вес:3,источник:'calls',evidence:{kind:'manual',adapter:null,weight:{base:9,scale:1,decay:1,override:3}}}
 ]}},'источники':{calendar:{статус:'live',capturedAt:'2026-01-01T12:00:00Z',expiresAt:'2026-01-02T12:00:00Z',заметка:'Expired receipt'}}};
 ({w,calls,q,click}=await mount({raw,demo:false}));
 assert(q('.classic-link a').href.endsWith('/classic'));
 assert.match(q('.head-actions').textContent,/YOUR PRIVATE BOARD/);
 assert(calls.some(([url])=>url==='/check-ins'));
 click('.record-row');
 assert(!q('.research-detail').querySelector('img,script'),'source text is escaped');
 assert.match(q('.research-detail').textContent,/2.000 base × 2.000 source scale × 1.000 decay = 4.000/);
 assert.match(q('.research-detail').textContent,/collector calendar/);
 assert.match(q('.research-detail').textContent,/snapshot expired/);
 click('[data-record="обязательства:1"]');
 assert.match(q('.research-detail').textContent,/manual override 3.000/);
 assert.match(q('.research-detail').textContent,/Undated|undated/);
 assert(!q('.research-detail').textContent.includes('not connected'),'manual source name is an annotation, not an unavailable API');
 click('[data-action="record-source"]');
 assert.equal(w.document.querySelectorAll('.record-row').length,1,'manual group filter uses canonical grouping');
 click('[data-action="clear-filters"]');click('[data-tab="today"]');click('[data-event="fictional-review"]');click('[data-action="save"]');await tick();
 assert(calls.some(([url,options])=>url==='/check-in'&&options?.method==='POST'));
 assert(!JSON.stringify(calls.find(([url])=>url==='/check-in')[1]).includes('Fictional design review'));
 assert.match(q('#workspace-main').textContent,/very pleasant · energy unchanged/,'POST uses server canonical entry');
 const previousFetch=w.fetch;w.fetch=async(url,options)=>url==='/check-ins'?{ok:false,status:503}:previousFetch(url,options);
 click('[data-action="refresh"]');await tick();
 assert.match(q('#workspace-main').textContent,/Check-in sync unavailable \(503\)/);
 assert.match(q('#workspace-main').textContent,/very pleasant · energy unchanged/,'failed GET retains known check-ins');
 w.close();
 const dense={...fixture,'лучи':{}};
 for(const [arm,count] of [['обязательства',48],['ресурсы',20],['прошлое',11],['будущее',16]])dense['лучи'][arm]={элементы:Array.from({length:count},(_,i)=>({id:arm+i,т:'Fictional dense record '+i,вес:3,ч:24,источник:'manual'}))};
 ({w,q,click}=await mount({raw:dense}));
 assert.equal(w.document.querySelectorAll('.record-row').length,95,'dense board exposes every matching record');
 for(const rect of w.document.querySelectorAll('.research-block rect')){assert(Number(rect.getAttribute('x'))>=0);assert(Number(rect.getAttribute('y'))>=0);assert(Number(rect.getAttribute('x'))+Number(rect.getAttribute('width'))<=1040);assert(Number(rect.getAttribute('y'))+Number(rect.getAttribute('height'))<=720);}
 click('[data-layout="time"]');
 for(const rect of w.document.querySelectorAll('.research-block rect'))assert(Number(rect.getAttribute('x'))+Number(rect.getAttribute('width'))<=1040,'dense time bars stay inside plot');
 w.close();
 ({w,q}=await mount({hash:'#today'}));assert.equal(q('[role="tab"][aria-selected=true]').dataset.tab,'today');w.close();
 console.log('PASS research: live identity reconciliation (reorder/removal/arm move/adapter identity/collisions), compact controls, responsive SVG constraints, four arm drilldowns, complete weight/time lists, modal drawer focus trap/Escape/return, immutable inspection, normalization, expiry, immutable weighted previews, complete cross/time/process renderer, filters, evidence receipts/formulas, fictional isolation, private check-in API, day preservation, history, keyboard and deep links');
})().catch(error=>{console.error(error);process.exit(1);});
