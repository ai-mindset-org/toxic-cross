document.getElementById('copy-agent')?.addEventListener('click',async()=>{const text=document.getElementById('agent-prompt').textContent;try{await navigator.clipboard.writeText(text);document.getElementById('copy-status').textContent=document.documentElement.lang==='ru'?'Промпт скопирован. Отдай его Claude Code или Codex.':'Prompt copied. Give it to Claude Code or Codex.';}catch{const range=document.createRange();range.selectNodeContents(document.getElementById('agent-prompt'));getSelection().removeAllRanges();getSelection().addRange(range);document.getElementById('copy-status').textContent='Select and copy the prompt above.';}});

document.addEventListener('aim:lang',()=>{const frame=document.getElementById('entry-cross');if(frame){const u=new URL(frame.src);u.searchParams.set('lang',document.documentElement.lang);frame.src=u.href;}});

{const frame=document.getElementById('entry-cross');if(frame){const lang=new URLSearchParams(location.search).get('lang')||localStorage.getItem('aim-apps-lang');if(lang==='ru'){const u=new URL(frame.src);u.searchParams.set('lang','ru');frame.src=u.href;}}}

document.getElementById('play-film')?.addEventListener('click',async()=>{const video=document.getElementById('krest-film-video');document.getElementById('play-film').hidden=true;video.hidden=false;video.muted=true;try{await video.play();}catch{video.focus();}});

// The guided field remains inside the existing demo document.
(()=>{
 const frame=document.getElementById('live-demo');if(!frame)return;
 const buttons=[...document.querySelectorAll('[data-tour-step]')],note=document.querySelector('.tour-explanation');
 function sync(){const u=new URL(frame.src);u.searchParams.set('lang',document.documentElement.lang);if(frame.src!==u.href){buttons.forEach(b=>b.disabled=true);frame.src=u.href;}}
 sync();document.addEventListener('aim:lang',sync);
 buttons.forEach(b=>b.addEventListener('click',()=>frame.contentWindow.postMessage({type:'krest:tour-step',action:b.dataset.tourStep},location.origin)));
 window.addEventListener('message',e=>{
  if(e.origin!==location.origin||e.source!==frame.contentWindow||e.data?.type!=='krest:tour')return;
  if(e.data.action==='ready')buttons.forEach(b=>b.disabled=false);
  buttons.forEach(b=>{if(b.dataset.tourStep===e.data.action)b.setAttribute('aria-current','step');else b.removeAttribute('aria-current');});
  if(typeof e.data.text==='string')note.textContent=e.data.text;
 });
})();
