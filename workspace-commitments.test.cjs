const assert=require('node:assert/strict');
const fs=require('node:fs');
const {JSDOM}=require(process.env.KREST_JSDOM||'jsdom');
const {safeReferences,registryRows,registryProjection}=require('./site/assets/workspace-v2.js');
assert.deepEqual(safeReferences({references:[
 {url:'javascript:alert(1)'},{url:'data:text/html,bad'},{url:'file:///private/note'},
 {url:'https://user:password@example.test/private'},{url:'https://example.test/path · annotation'},
 {url:'https://example.test/source',label:'Original meeting'},
 {url:'https://example.test/source',label:'Duplicate'},
 {url:'https://example.test/registry#promise-fictional',label:'Registry',id:'fictional-promise'}
]}),[
 {url:'https://example.test/source',label:'Original meeting',id:''},
 {url:'https://example.test/registry#promise-fictional',label:'Registry',id:'fictional-promise'}
]);
assert.equal(safeReferences({'путь':'caLena promises.some-id'}).length,0,'a source label is not guessed into a URL');
const reg={records:[{id:'promise-synthetic',status:'open'}]},representative={id:'DEMO-1',вес:3,commitment:{inputs:[{promiseId:'promise-synthetic'}]}};
assert.equal(registryProjection(reg,[representative]).records[0].influence.representativeWeight,3);
assert.equal(registryProjection(reg,[],[{record:representative}]).records[0].influence.kind,'hidden');
assert.equal(registryProjection(reg,[]).records[0].influence.weight,0);
const fixture=JSON.parse(fs.readFileSync('site/example-v2.json','utf8'));
fixture.promiseRegistry={fresh:true,source_last_success_at:'2026-10-20T10:00Z',checked_at:'2026-10-20T10:01Z',records:Array.from({length:31},(_,i)=>({id:'synthetic-'+i,title:'Synthetic promise '+i,status:'open',kind:'task',confirmation:'machine-extracted',flags:i===0?['old']:[],deadline:{kind:i===1?'exact':'window',overdue:i===1,label:i===1?'Oct 19':'That week; exact day unknown'},influence:{kind:'candidate',weight:0}}))};
assert.equal(registryRows(fixture.promiseRegistry,'overdue').length,1);
assert.equal(registryRows(fixture.promiseRegistry,'old').length,1);
assert.equal(registryRows(fixture.promiseRegistry,'needs-date').length,30);
assert.equal(registryRows(fixture.promiseRegistry,'','Synthetic promise 30').length,1);
const item=fixture['лучи']['обязательства']['элементы'][0];
item.commitment={canonicalId:'fictional-commitment',policy:'One representative weight',reason:'Explicitly linked synthetic evidence.',inputs:[{source:'tasks',id:'DEMO-1',weight:3,representative:true},{source:'promises',id:'fictional-promise',weight:2}]};
item.references=[{url:'https://example.test/registry#fictional-promise',label:'Open registry'},{url:'javascript:alert(1)',label:'unsafe'}];
const w=new JSDOM('<div id="krest-workspace" data-mode="demo" data-context="fixture.json"></div>',{url:'https://demo.example.test/#research',runScripts:'outside-only'}).window;
w.fetch=async()=>({ok:true,json:async()=>fixture});
w.HTMLDialogElement.prototype.close=function(){this.open=false;};
w.eval(fs.readFileSync('site/assets/workspace-v2.js','utf8'));
setTimeout(()=>{
 try{
  w.document.querySelector('.record-row').click();
  const panel=w.document.querySelector('.research-detail');
  assert.match(panel.textContent,/One commitment, linked evidence/);
  assert.match(panel.textContent,/fictional-commitment/);
  assert.match(panel.textContent,/counted representative/);
  const links=[...panel.querySelectorAll('.source-references a')];
  assert.equal(links.length,1);assert.equal(links[0].href,'https://example.test/registry#fictional-promise');
  assert.equal(links[0].rel,'noopener noreferrer');
  assert(!panel.innerHTML.includes('javascript:'));
  panel.querySelector('[data-action=clear-record]').click();
  w.document.querySelector('[data-tab=sources]').click();
  assert.equal(w.document.querySelectorAll('.registry-record').length,25);
  w.document.querySelector('[data-action=registry-more]').click();
  assert.equal(w.document.querySelectorAll('.registry-record').length,31);
  const select=w.document.querySelector('#registry-filter');select.value='overdue';select.dispatchEvent(new w.Event('change',{bubbles:true}));
  assert.equal(w.document.querySelectorAll('.registry-record').length,1);
  assert.match(w.document.querySelector('.promise-registry').textContent,/source status stays separate from Linear status/);
  console.log('PASS commitment inspection: explicit source references, safe links, dedup provenance and synthetic-only fixture');
 }finally{w.close();}
},30);
