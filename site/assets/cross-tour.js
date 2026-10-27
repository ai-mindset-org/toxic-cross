/* A fictional, read-only walkthrough using the shared Cross renderer. */
(()=>{
  if(!document.documentElement.hasAttribute('data-krest-tour'))return;
  const ru=new URLSearchParams(location.search).get('lang')==='ru';
  const arms=['обязательства','ресурсы','прошлое','будущее'];
  const names=ru?arms:['obligations','resources','past','future'];
  const t=(en,rus)=>ru?rus:en, esc=window.KrestWorkspace.esc;
  const host=document.getElementById('krest-workspace');
  const shell=document.createElement('div');shell.className='tour-shell';host.before(shell);shell.append(host);
  shell.insertAdjacentHTML('afterbegin',`<p class="tour-caption">${t('Fictional day · select any block','Вымышленный день · нажми любой блок')}</p>`);
  shell.insertAdjacentHTML('beforeend',`<div class="tour-tools"><label>${t('Direction','Луч')}<select id="tour-arm">${arms.map((a,i)=>`<option value="${a}" ${i===1?'selected':''}>${names[i]}</option>`).join('')}</select></label><label>${t('Window','Окно')}<select id="tour-window"><option value="168">${t('7 days','7 дней')}</option><option value="720">${t('30 days','30 дней')}</option><option value="8760" selected>${t('1 year','1 год')}</option></select></label><button data-tour="one">${t('flip one','перевернуть один')}</button><button data-tour="all">${t('flip all four','перевернуть четыре')}</button><button data-tour="reset">${t('reset','сначала')}</button></div><div class="tour-card" id="tour-card" role="region" aria-label="${t('Block calculation','Расчёт блока')}"></div><p class="tour-result" role="status"></p>`);
  const card=shell.querySelector('#tour-card'),status=shell.querySelector('.tour-result');
  let original,selected='',factors={},windows={},timer=null,activeArm='',step='';
  const reduced=matchMedia('(prefers-reduced-motion: reduce)').matches;
  const stop=()=>{clearInterval(timer);timer=null;shell.classList.remove('tour-recoiling');host.querySelector('.recoil-pull')?.remove();};
  const tell=(action,text)=>{step=action;status.textContent=text;parent.postMessage({type:'krest:tour',action,text},location.origin);};
  function records(){return window.KrestWorkspace.recordsOf(original);}
  function showCard(){
    const r=records().find(r=>r.key===selected);
    if(!r){card.innerHTML=`<h3>${t('A block is one fact with a declared weight.','Блок – один факт с заданным весом.')}</h3><p>${t('Select a block to see its source and calculation. Try the four steps beside the field.','Нажми блок: увидишь источник и расчёт. Пройди четыре шага рядом с полем.')}</p>`;return;}
    const w=r.evidence.weight||{},half={'ситуативное':1,'недельное':7,'глобальное':45}[r.scope];
    card.innerHTML=`<h3>${esc(r.title)}</h3><p>${esc(r.fact)}</p><dl><dt>${t('source','источник')}</dt><dd>${esc(ru?r.source:({'задачи':'tasks','календарь':'calendar','фокус':'daily focus','правки':'manual changes'}[r.source]||r.source))}</dd><dt>${t('base × source × decay','база × масштаб × затухание')}</dt><dd>${Number(w.base??r.weight).toFixed(2)} × ${Number(w.scale??1).toFixed(2)} × ${Number(w.decay??1).toFixed(2)} = ${r.weight.toFixed(2)}</dd><dt>${t('half-life','полураспад')}</dt><dd>${half??'?'} ${t(half===1?'day':'days','дн.')} · ${esc(ru?r.scope:({'ситуативное':'situational','недельное':'weekly','глобальное':'global'}[r.scope]||r.scope))}</dd><dt>${t('flip multiplier','множитель переворота')}</dt><dd>× ${(factors[r.arm]??1).toFixed(3)} · ${t('preview weight','вес в демо')} ${(r.weight*(factors[r.arm]??1)).toFixed(2)}</dd></dl>`;
  }
  function render(){
    const frame=JSON.parse(JSON.stringify(original));frame.tourWindows=windows;
    for(const [arm,a]of Object.entries(frame['лучи'])){
      a['подпись']=names[arms.indexOf(arm)];
      for(const item of a['элементы'])item['вес']*=factors[arm]??1;
    }
    const base=window.KrestWorkspace.recordBalance(records()).sums;
    const scale=Math.max(1,arms.reduce((sum,a)=>sum+Math.abs(base[a]),0)/2);
    const sums=window.KrestWorkspace.recordBalance(window.KrestWorkspace.recordsOf(frame)).sums;
    const clamp=v=>Math.max(-1,Math.min(1,v));
    frame['баланс']={x:clamp((sums['будущее']-sums['прошлое'])/scale),y:clamp((sums['ресурсы']-sums['обязательства'])/scale)};window.KrestPreview.update(frame);
    host.querySelectorAll('.research-block').forEach(el=>{
      const rect=el.querySelector('rect'),hit=rect.cloneNode();
      const x=+rect.getAttribute('x'),y=+rect.getAttribute('y'),w=+rect.getAttribute('width'),h=+rect.getAttribute('height');
      hit.setAttribute('class','tour-hit');hit.setAttribute('x',x-(Math.max(56,w)-w)/2);hit.setAttribute('y',y-(Math.max(56,h)-h)/2);hit.setAttribute('width',Math.max(56,w));hit.setAttribute('height',Math.max(56,h));el.prepend(hit);
      el.classList.toggle('tour-selected',el.dataset.record===selected);
      el.classList.toggle('tour-arm-active',el.dataset.record.startsWith(activeArm+':'));
    });
    if(timer){
      const svg=host.querySelector('svg'),g=document.createElementNS('http://www.w3.org/2000/svg','g');g.setAttribute('class','recoil-pull');
      const ends={'обязательства':[520,110],'ресурсы':[520,610],'прошлое':[130,360],'будущее':[910,360]},[x,y]=ends[activeArm];
      for(const arm of arms.filter(a=>a!==activeArm)){const [a,b]=ends[arm],p=document.createElementNS(svg.namespaceURI,'path');p.setAttribute('d',`M${a} ${b} Q520 360 ${x} ${y}`);g.append(p);}svg.prepend(g);
    }
    showCard();
  }
  function act(action){
    if(!original)return;
    if(action==='block'){
      stop();
      const r=records().find(r=>r.arm==='обязательства'&&r.evidence.weight)||records()[0];selected=r.key;activeArm=r.arm;render();
      tell(action,t('The card shows the source, base weight, scale and half-life.','Карточка показывает источник, базовый вес, масштаб и полураспад.'));return;
    }
    if(action==='one'){
      stop();factors={};activeArm=shell.querySelector('#tour-arm').value;selected=records().find(r=>r.arm===activeArm)?.key||selected;factors[activeArm]=.25;
      const started=performance.now();
      const tick=()=>{
        const progress=reduced?1:Math.min(1,(performance.now()-started)/26000);
        factors[activeArm]=.25+.75*.75*progress;render();
        if(progress===1){stop();tell(action,t('Neighbours returned 75% of the removed weight. The single-arm flip recoils.','Соседи вернули 75% снятого веса. Один луч откатился.'));}
      };
      tell(action,t('One arm is lighter. Neighbours pull 75% of the removed weight back over 26 seconds.','Один луч стал легче. Соседи вернут 75% снятого веса за 26 секунд.'));
      timer=setInterval(tick,100);shell.classList.add('tour-recoiling');tick();return;
    }
    if(action==='all'){
      stop();activeArm='';factors=Object.fromEntries(arms.map(a=>[a,.25]));render();
      tell(action,t('All four weights stay at ×0.25. There is no recoil.','Все четыре веса остаются ×0.25. Отката нет.'));return;
    }
    if(action==='window'){
      stop();
      activeArm=shell.querySelector('#tour-arm').value;const select=shell.querySelector('#tour-window');
      select.value=select.value==='168'?'8760':'168';
      windows[activeArm]=+select.value;render();
      tell(action,t('This arm has a new time window; the full snapshot balance is retained.','Окно этого луча изменилось; баланс полного снимка сохранён.'));return;
    }
    stop();selected=activeArm='';factors={};windows={};shell.querySelector('#tour-window').value='8760';render();tell('reset',t('Original fictional day restored.','Исходный вымышленный день восстановлен.'));
  }
  host.addEventListener('click',e=>{
    const block=e.target.closest('[data-record]');if(!block)return;
    stop();selected=block.dataset.record;activeArm=selected.split(':')[0];render();tell('block',t('The selected block keeps its original source receipt.','У выбранного блока виден исходный расчёт.'));
  });
  host.addEventListener('keydown',e=>{if((e.key==='Enter'||e.key===' ')&&e.target.closest('[data-record]')){e.preventDefault();e.target.closest('[data-record]').dispatchEvent(new MouseEvent('click',{bubbles:true}));}});
  shell.addEventListener('click',e=>{const button=e.target.closest('[data-tour]');if(button)act(button.dataset.tour);});
  shell.querySelector('#tour-arm').addEventListener('change',e=>{shell.querySelector('#tour-window').value=String(windows[e.target.value]||8760);});
  shell.querySelector('#tour-window').addEventListener('change',e=>{stop();activeArm=shell.querySelector('#tour-arm').value;windows[activeArm]=+e.target.value;step='window';render();tell('window',t('The time window changed for this arm.','Временное окно этого луча изменилось.'));});
  window.addEventListener('message',e=>{if(e.origin===location.origin&&e.source===parent&&e.data?.type==='krest:tour-step'&&['block','one','all','window','reset'].includes(e.data.action))act(e.data.action);});
  window.addEventListener('pagehide',stop);
  fetch('example-v2.json').then(r=>{if(!r.ok)throw Error('fixture');return r.json();}).then(raw=>{original=raw;render();tell('ready',t('Select a block, or start with step 1. All data is fictional.','Нажми блок или начни с шага 1. Все данные вымышленные.'));}).catch(()=>{status.textContent=t('Example unavailable. Reload to try again.','Пример недоступен. Обнови страницу.');});
})();
