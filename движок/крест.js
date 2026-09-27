/* крест · публичный рендерер примера · без зависимостей · global KREST
   KREST.mount(el, data, {layout, compact, panel}) → instance
   Луч это таймлайн от центра: положение = время (лог-шкала), размер блока = вес, толщина = охват.
   Переворот: полный держится, частичный откатывается (соседние лучи отыгрывают вес обратно). */
(function (root) {
  'use strict';

  var ORDER = ['обязательства', 'будущее', 'ресурсы', 'прошлое'];
  var DIR = { 'обязательства': [0, -1], 'будущее': [1, 0], 'ресурсы': [0, 1], 'прошлое': [-1, 0] };
  var THICK = { 'ситуативное': 6, 'недельное': 10, 'глобальное': 14 };
  var WINDOWS = [6, 24, 72, 168, 720, 2160, 8760];
  var WNAME = { 6: '6 ч', 24: 'сутки', 72: '3 дня', 168: 'неделя', 720: 'месяц', 2160: '3 мес', 8760: 'год' };
  var ROLL_MAX = 0.75, ROLL_MS = 26000;
  var INK = '#202124', MUTED = '#6b6e75', LINE = '#e8e9ed', LINE2 = '#c9cbd1', RED = '#db303d', WASH = '#f2f3f5';

  function esc(s) {
    return String(s == null ? '' : s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  }
  function n(v) { return Math.round(v * 10) / 10; }
  function clamp(v, a, b) { return v < a ? a : v > b ? b : v; }
  function reduced() {
    return root.matchMedia && root.matchMedia('(prefers-reduced-motion: reduce)').matches;
  }
  function pos(hours, win) {
    var h = Math.abs(hours);
    return clamp(Math.log10(1 + h) / Math.log10(1 + win), 0, 1);
  }

  function mount(el, data, opts) {
    opts = opts || {};
    var S = {
      data: data,
      layout: opts.layout || 'крест',
      compact: !!opts.compact,
      panel: opts.panel !== false,
      win: {}, flip: {}, mark: {},
      roll: 0, rollFrom: 0,
      ball: { x: 0, y: 0, vx: 0, vy: 0 },
      sel: null, hover: null, dirty: true, last: 0
    };
    ORDER.forEach(function (l) { S.win[l] = 8760; S.flip[l] = false; });

    el.classList.add('krest');
    el.innerHTML =
      '<div class="bar"></div>' +
      (S.compact ? '' : '<div class="src"></div>') +
      '<div class="stage"><svg class="field" role="img" aria-label="крест на выдуманном дне"></svg><div class="tip"></div></div>' +
      '<div class="foot"></div>' +
      (S.panel ? '<div class="card-el"></div>' : '');
    var bar = el.querySelector('.bar'), stage = el.querySelector('.stage'),
      svg = el.querySelector('svg.field'), tip = el.querySelector('.tip'),
      foot = el.querySelector('.foot'), panel = el.querySelector('.card-el'),
      srcline = el.querySelector('.src');

    /* --- веса --- */
    function eff(e) {
      var k = 1, lf = S.flip[e.луч], bf = !!S.mark[e.id];
      var back = S.roll / ROLL_MAX;                       /* 0 = свежий переворот, 1 = отыграно */
      if (lf) k = 0.25 + 0.75 * S.roll;
      if (bf) k = Math.min(k, 0.25);
      if (e.вес < 0) return e.вес * (lf ? back : 1) * (bf ? 0 : 1);
      return e.вес * k;
    }
    function items() {
      var out = [];
      ORDER.forEach(function (l) {
        (S.data.лучи[l].элементы || []).forEach(function (e) {
          e.луч = l; e.толщина = THICK[e.охват] || 10; out.push(e);
        });
      });
      return out;
    }
    function sums() {
      var s = {}; ORDER.forEach(function (l) { s[l] = 0; });
      items().forEach(function (e) { s[e.луч] += eff(e); });
      return s;
    }
    function flipped() { return ORDER.filter(function (l) { return S.flip[l]; }).length; }

    /* --- шар --- */
    function target() {
      var s = sums(), total = 0;
      ORDER.forEach(function (l) { total += Math.abs(s[l]); });
      var sc = total / 2 || 1;
      return { x: clamp((s['будущее'] - s['прошлое']) / sc, -1, 1), y: clamp(-(s['обязательства'] - s['ресурсы']) / sc, -1, 1) };
    }
    function step(dt) {
      var t = target(), b = S.ball, k = 6, c = 2.2;
      b.vx += (k * (t.x - b.x) - c * b.vx) * dt;
      b.vy += (k * (t.y - b.y) - c * b.vy) * dt;
      b.x += b.vx * dt; b.y += b.vy * dt;
      return Math.abs(b.vx) + Math.abs(b.vy) + Math.abs(t.x - b.x) + Math.abs(t.y - b.y) > 0.002;
    }

    /* --- геометрия --- */
    function box() {
      var w = el.clientWidth || 900;
      if (w < 560) return { W: 430, H: 560, small: true };
      return S.compact ? { W: 780, H: 520 } : { W: 900, H: 620 };
    }

    function drawKrest() {
      var g = box(), W = g.W, H = g.H, cx = W / 2, cy = H / 2;
      var armX = cx - (g.small ? 46 : 96), armY = cy - 72, s = sums(), out = '', labels = '', over = {};
      var lane = {}, top = {}, dayView = S.layout === 'день';
      function winOf(l) { return dayView ? 24 : S.win[l]; }
      ORDER.forEach(function (l) {
        lane[l] = { side: 1, lastA: {}, tier: {}, lastY: {} };
        top[l] = (S.data.лучи[l].элементы || []).slice().sort(function (a, b) { return Math.abs(eff(b)) - Math.abs(eff(a)); })
          .slice(0, 4).map(function (e) { return e.id; });
      });
      /* засечки */
      ORDER.forEach(function (l) {
        var d = DIR[l], len = d[0] ? armX : armY, win = winOf(l);
        out += '<line x1="' + cx + '" y1="' + cy + '" x2="' + (cx + d[0] * len) + '" y2="' + (cy + d[1] * len) + '" stroke="' + LINE2 + '"/>';
        WINDOWS.forEach(function (w) {
          if (w > win) return;
          var p = pos(w, win), x = cx + d[0] * (26 + p * (len - 46)), y = cy + d[1] * (26 + p * (len - 46));
          out += '<circle cx="' + n(x) + '" cy="' + n(y) + '" r="1.4" fill="' + LINE2 + '"/>';
          if (!g.small) out += '<text x="' + n(x + (d[0] ? 0 : 7)) + '" y="' + n(y + (d[0] ? 13 : 0)) + '" fill="' + LINE2 + '" font-size="8.5" text-anchor="' + (d[0] ? 'middle' : 'start') + '">' + WNAME[w] + '</text>';
        });
      });
      /* блоки */
      items().forEach(function (e, i) {
        var l = e.луч, d = DIR[l], len = d[0] ? armX : armY, win = winOf(l);
        if (Math.abs(e.ч) > win && !e.просрочено) { over[l] = (over[l] || 0) + 1; return; }
        var w = eff(e), aw = Math.abs(w);
        var p = e.просрочено ? 0 : pos(e.ч, win);
        var dist = 26 + p * (len - 46);
        var x = cx + d[0] * dist, y = cy + d[1] * dist;
        var along = 9 + aw * (g.small ? 5.5 : 7), cross = e.толщина * (g.small ? 1.1 : 1.35);
        var bw = d[0] ? along : cross, bh = d[0] ? cross : along;
        var hot = S.hover === e.id || S.sel === e.id;
        var deficit = e.вес < 0, marked = !!S.mark[e.id] || S.flip[l];
        var fill = deficit ? RED : marked ? '#fff' : hot ? INK : '#fff';
        var stroke = deficit ? RED : e.просрочено ? RED : hot ? INK : marked ? LINE2 : INK;
        if (!marked && !deficit && !hot) fill = WASH;
        out += '<rect class="blk" data-id="' + esc(e.id) + '" x="' + n(x - bw / 2) + '" y="' + n(y - bh / 2) + '" width="' + n(bw) + '" height="' + n(bh) +
          '" fill="' + fill + '" stroke="' + stroke + '" stroke-width="' + (marked ? 1 : 1.2) + '"' + (marked ? ' stroke-dasharray="3 2"' : '') + ' style="cursor:pointer"/>';
        if (hot || (!g.small && top[l].indexOf(e.id) >= 0)) {
          var L = lane[l], side = L.side; L.side = -side;
          if (!d[0] && p < 0.05) side = -1;
          var key = side > 0 ? 'p' : 'm', along0 = d[0] ? x : y, gap = d[0] ? 150 : 15;
          L.tier[key] = (L.lastA[key] != null && Math.abs(along0 - L.lastA[key]) < gap) ? (L.tier[key] || 0) + 1 : 0;
          L.lastA[key] = along0;
          var off = (d[0] ? bh / 2 + (side > 0 ? 24 : 11) : bw / 2 + 11) + (d[0] ? L.tier[key] * 13 : 0);
          var tx, ty, anchor;
          if (d[0]) { tx = x; ty = y + side * off + (side > 0 ? 4 : -2); anchor = 'middle'; }
          else {
            tx = x + side * off; ty = y + 3.5; anchor = side > 0 ? 'start' : 'end';
            if (L.lastY[key] != null && ty - L.lastY[key] < 13) ty = L.lastY[key] + 13;
            L.lastY[key] = ty;
          }
          var txt = (marked && e.флип) ? e.флип : e.т;
          if (txt.length > 30) txt = txt.slice(0, 29) + '…';
          labels += '<text x="' + n(tx) + '" y="' + n(ty) + '" text-anchor="' + anchor + '" font-size="' + (hot ? 10.5 : 9.5) +
            '" fill="' + (hot ? INK : MUTED) + '" stroke="#fff" stroke-width="2.6" paint-order="stroke" stroke-linejoin="round">' + esc(txt) + '</text>';
        }
      });
      /* подписи лучей и пульт */
      ORDER.forEach(function (l) {
        var d = DIR[l], len = d[0] ? armX : armY;
        var x = cx + d[0] * (len + 8), y = cy + d[1] * (len + 8);
        var anchor = d[0] > 0 ? 'end' : d[0] < 0 ? 'start' : 'middle';
        var ty = d[1] < 0 ? y - 26 : d[1] > 0 ? y + 34 : cy - Math.round(armY * (g.small ? 0.72 : 0.42));
        var head = g.small ? l + ' · ' + n(s[l]) : l + ' · ' + n(s[l]) + ' · окно ' + WNAME[winOf(l)];
        labels += '<text x="' + n(x) + '" y="' + n(ty) + '" text-anchor="' + anchor + '" font-size="10.5" fill="' + (S.flip[l] ? RED : INK) + '">' + esc(head) + '</text>';
        labels += '<text x="' + n(x) + '" y="' + n(ty + 15) + '" text-anchor="' + anchor + '" font-size="10" fill="' + MUTED + '">' +
          (dayView ? '' :
            '<tspan class="act" data-act="win-" data-arm="' + l + '" style="cursor:pointer">[ − ]</tspan> ' +
            '<tspan class="act" data-act="win+" data-arm="' + l + '" style="cursor:pointer">[ + ]</tspan> ') +
          '<tspan class="act" data-act="flip" data-arm="' + l + '" style="cursor:pointer" fill="' + (S.flip[l] ? RED : MUTED) + '">' + (g.small ? '[ пер ]' : '[ перевернуть ]') + '</tspan>' +
          (over[l] ? '<tspan fill="' + LINE2 + '"> + ' + over[l] + ' за окном</tspan>' : '') +
          '</text>';
      });
      var b = S.ball, bx = cx + b.x * (armX * 0.42), by = cy + b.y * (armY * 0.42);
      out += '<circle cx="' + n(cx) + '" cy="' + n(cy) + '" r="2" fill="' + LINE2 + '"/>';
      out += '<line x1="' + n(cx) + '" y1="' + n(cy) + '" x2="' + n(bx) + '" y2="' + n(by) + '" stroke="' + RED + '" stroke-opacity=".35"/>';
      out += '<circle cx="' + n(bx) + '" cy="' + n(by) + '" r="7" fill="' + RED + '"/>';
      return { W: W, H: H, body: out + labels };
    }

    function drawTime() {
      var g = box(), W = g.W, cx = W / 2, pad = g.small ? 26 : 58, half = W / 2 - pad;
      var win = 8760, sc = g.small ? 26 : 22, out = '', labels = '';
      var list = items().map(function (e) {
        var w = eff(e), aw = Math.abs(w);
        var sign = (e.луч === 'прошлое' || e.ч < 0) ? -1 : 1;
        var up = e.луч === 'обязательства' || e.вес < 0 || (e.луч === 'будущее' && !e.опора);
        return { e: e, x: cx + sign * pos(e.ч, win) * half, h: Math.max(5, aw * sc), up: up };
      });
      var maxUp = 30, maxDown = 30;
      list.forEach(function (b) { if (b.up) maxUp = Math.max(maxUp, b.h); else maxDown = Math.max(maxDown, b.h); });
      var y0 = 46 + maxUp, H = y0 + maxDown + 62;
      out += '<line x1="' + pad + '" y1="' + n(y0) + '" x2="' + (W - pad) + '" y2="' + n(y0) + '" stroke="' + LINE2 + '"/>';
      var tickY = y0 + maxDown + 26;
      [-8760, -720, -168, -24, 24, 168, 720, 8760].forEach(function (h) {
        var x = cx + (h < 0 ? -1 : 1) * pos(h, win) * half;
        out += '<line x1="' + n(x) + '" y1="' + n(y0 - 4) + '" x2="' + n(x) + '" y2="' + n(y0 + 4) + '" stroke="' + LINE2 + '"/>' +
          '<line x1="' + n(x) + '" y1="' + n(y0 + 6) + '" x2="' + n(x) + '" y2="' + n(tickY - 10) + '" stroke="' + LINE + '"/>' +
          '<text x="' + n(x) + '" y="' + n(tickY) + '" font-size="9" fill="' + MUTED + '" text-anchor="middle">' + (h < 0 ? '\u2212' : '+') + WNAME[Math.abs(h)] + '</text>';
      });
      out += '<line x1="' + n(cx) + '" y1="' + n(y0 - maxUp - 22) + '" x2="' + n(cx) + '" y2="' + n(tickY - 10) + '" stroke="' + LINE2 + '"/>' +
        '<text x="' + n(cx + 5) + '" y="' + n(y0 - maxUp - 26) + '" font-size="9.5" fill="' + MUTED + '">сейчас</text>';
      labels += '<text x="' + pad + '" y="' + n(y0 - maxUp - 26) + '" font-size="10" fill="' + MUTED + '">вверх долг · вниз опора · горизонталь только время</text>';
      list.forEach(function (b) {
        var e = b.e, hot = S.hover === e.id || S.sel === e.id, marked = !!S.mark[e.id] || S.flip[e.луч];
        var y = b.up ? y0 - b.h : y0;
        var fill = e.вес < 0 ? RED : hot ? INK : marked ? '#fff' : WASH;
        out += '<rect class="blk" data-id="' + esc(e.id) + '" x="' + n(b.x - 5) + '" y="' + n(y) + '" width="10" height="' + n(b.h) +
          '" fill="' + fill + '" stroke="' + (e.просрочено || e.вес < 0 ? RED : hot ? INK : LINE2) + '" style="cursor:pointer"/>';
        if (hot) {
          var t = e.т.length > 40 ? e.т.slice(0, 39) + '\u2026' : e.т;
          labels += '<text x="' + n(b.x) + '" y="' + n(b.up ? y - 7 : y + b.h + 14) + '" font-size="10.5" fill="' + INK +
            '" text-anchor="middle" stroke="#fff" stroke-width="2.6" paint-order="stroke" stroke-linejoin="round">' + esc(t) + '</text>';
        }
      });
      return { W: W, H: H, body: out + labels };
    }

    /* --- сборка --- */
    function render() {
      var d = S.layout === 'время' ? drawTime() : drawKrest();
      svg.setAttribute('viewBox', '0 0 ' + d.W + ' ' + d.H);
      svg.innerHTML = '<g font-family="AIMPlex, ui-monospace, monospace">' + d.body + '</g>';
      renderBar(); renderFoot(); renderPanel();
    }
    function renderBar() {
      var f = flipped();
      bar.innerHTML =
        '<span class="picker">' + ['крест', 'время', 'день'].map(function (l) {
          return '<button data-layout="' + l + '" aria-pressed="' + (S.layout === l) + '">' + l + '</button>';
        }).join('') + '</span>' +
        '<button class="btn" data-all="1" aria-pressed="' + (f === 4) + '">перевернуть всё</button>' +
        '<button class="btn" data-reset="1">сброс</button>' +
        '<span class="sep"></span>' +
        '<span style="color:' + MUTED + '">' + esc(S.data.дата) + ' · выдуманный день</span>';
    }
    function renderFoot() {
      var f = flipped(), parts = [];
      parts.push('клавиши: <kbd>f</kbd> перевернуть всё · <kbd>r</kbd> сброс · <kbd>1</kbd>–<kbd>4</kbd> один луч');
      if (f > 0 && f < 4) parts.push('<span class="roll">откат ' + Math.round(S.roll / ROLL_MAX * 100) + ' % · перевёрнуто ' + f + ' из 4, соседние тянут обратно</span>');
      if (f === 4) parts.push('<span class="roll">перевёрнуты все четыре: держится, отката нет</span>');
      foot.innerHTML = parts.join('');
    }
    function renderPanel() {
      if (!panel) return;
      var e = S.sel && items().filter(function (i) { return i.id === S.sel; })[0];
      if (!e) { panel.innerHTML = '<span class="l">выбери блок: факт, вес, источник и флип</span>'; return; }
      panel.innerHTML =
        '<div><b>' + esc(e.т) + '</b></div>' +
        '<div class="l">луч ' + esc(e.луч) + ' · вес ' + n(eff(e)) + ' из ' + e.вес + ' · охват ' + esc(e.охват) + ' · источник ' + esc(e.источник) + '</div>' +
        '<div>' + esc(e.факт || '') + '</div>' +
        '<div class="flip">флип: ' + esc(e.флип) + '</div>' +
        '<div style="margin-top:8px"><button class="btn" data-mark="' + esc(e.id) + '" aria-pressed="' + !!S.mark[e.id] + '">уже перевернул этот блок</button></div>';
    }
    function renderSources() {
      if (!srcline) return;
      srcline.innerHTML = Object.keys(S.data.источники).map(function (k) {
        var s = S.data.источники[k];
        return '<span data-s="' + esc(s.статус) + '" title="' + esc(s.заметка) + '">' + esc(k) + ' · ' + esc(s.статус) + '</span>';
      }).join('');
    }

    /* --- события --- */
    function setFlip(l, v) {
      S.flip[l] = v;
      var f = flipped();
      if (f === 0 || f === 4) { S.roll = 0; S.rollFrom = 0; } else S.rollFrom = performance.now() - S.roll / ROLL_MAX * ROLL_MS;
      S.dirty = true;
    }
    el.addEventListener('click', function (ev) {
      var t = ev.target, a = t.getAttribute && t.getAttribute('data-act');
      if (t.dataset && t.dataset.layout) { S.layout = t.dataset.layout; S.dirty = true; return; }
      if (t.dataset && t.dataset.all) { var on = flipped() < 4; ORDER.forEach(function (l) { setFlip(l, on); }); return; }
      if (t.dataset && t.dataset.reset) { ORDER.forEach(function (l) { S.flip[l] = false; S.win[l] = 8760; }); S.mark = {}; S.roll = 0; S.sel = null; S.dirty = true; return; }
      if (t.dataset && t.dataset.mark) { S.mark[t.dataset.mark] = !S.mark[t.dataset.mark]; S.dirty = true; return; }
      if (a) {
        var l = t.getAttribute('data-arm'), i = WINDOWS.indexOf(S.win[l]);
        if (a === 'win-') S.win[l] = WINDOWS[Math.max(0, i - 1)];
        if (a === 'win+') S.win[l] = WINDOWS[Math.min(WINDOWS.length - 1, i + 1)];
        if (a === 'flip') setFlip(l, !S.flip[l]);
        S.dirty = true; return;
      }
      if (t.classList && t.classList.contains('blk')) { S.sel = t.getAttribute('data-id'); S.dirty = true; }
    });
    stage.addEventListener('mousemove', function (ev) {
      var t = ev.target, id = t.classList && t.classList.contains('blk') ? t.getAttribute('data-id') : null;
      if (id !== S.hover) { S.hover = id; S.dirty = true; }
      if (!id) { tip.className = 'tip'; return; }
      var e = items().filter(function (i) { return i.id === id; })[0];
      if (!e) return;
      var r = stage.getBoundingClientRect();
      tip.innerHTML = '<b>' + esc(e.т) + '</b><br>вес ' + n(eff(e)) + ' · ' + esc(e.источник) + '<span class="f">флип: ' + esc(e.флип) + '</span>';
      tip.className = 'tip on';
      tip.style.left = clamp(ev.clientX - r.left + 14, 4, r.width - 250) + 'px';
      tip.style.top = clamp(ev.clientY - r.top + 12, 4, r.height - 60) + 'px';
    });
    root.addEventListener('resize', function () { S.dirty = true; });
    stage.addEventListener('mouseleave', function () { tip.className = 'tip'; S.hover = null; S.dirty = true; });
    root.addEventListener('keydown', function (ev) {
      if (ev.metaKey || ev.ctrlKey || ev.altKey) return;
      var k = ev.key.toLowerCase();
      if (k === 'f' || k === 'а') { var on = flipped() < 4; ORDER.forEach(function (l) { setFlip(l, on); }); }
      else if (k === 'r' || k === 'к') { ORDER.forEach(function (l) { S.flip[l] = false; }); S.mark = {}; S.roll = 0; S.dirty = true; }
      else if ('1234'.indexOf(k) >= 0) setFlip(ORDER[+k - 1], !S.flip[ORDER[+k - 1]]);
    });

    /* --- цикл --- */
    var lastPaint = 0;
    function frame(now) {
      var dt = Math.min(0.05, (now - (S.last || now)) / 1000); S.last = now;
      var f = flipped(), moving = step(dt);
      if (f > 0 && f < 4) {
        var p = clamp((now - S.rollFrom) / ROLL_MS, 0, 1);
        var nv = ROLL_MAX * (1 - Math.pow(1 - p, 2));
        if (Math.abs(nv - S.roll) > 0.002) { S.roll = nv; S.dirty = true; }
      }
      if ((S.dirty || moving) && now - lastPaint > 40) { render(); lastPaint = now; S.dirty = false; }
      requestAnimationFrame(frame);
    }
    renderSources(); render();
    if (reduced()) { S.ball = target(); S.ball.vx = S.ball.vy = 0; render(); }
    requestAnimationFrame(frame);
    return { state: S, render: render };
  }

  root.KREST = { mount: mount, ORDER: ORDER, WINDOWS: WINDOWS, version: 1 };
})(window);
