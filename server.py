#!/usr/bin/env python3
"""Статика креста + маленькая запись правок. Только loopback, наружу отдаёт tailscale serve.

GET  /                     борт
GET  /отклик?...           страница ответа на вопрос пса (кнопки в боте ведут сюда)
POST /правка               {id, луч?, вес?, перевёрнут?, текст?}  → источники/правки.json
POST /отклик               {событие, луч, текст, вес}             → источники/отклики.json
"""
import http.server, socketserver, os, sys, json, pathlib, datetime, urllib.parse, threading, re, importlib, math, hashlib

_here=pathlib.Path(__file__).resolve().parent
КОРЕНЬ = pathlib.Path(os.environ.get('KREST_ROOT', _here.parent if _here.name=='сервер' else _here)).resolve()
_module_root = _here.parent if _here.name == 'сервер' else _here
if str(_module_root) not in sys.path: sys.path.insert(0, str(_module_root))
from provenance import adapter_evidence, weight_evidence, receipt, atomic_json, item_decay
ПОРТ = int(os.environ.get('KREST_PORT', '8452'))
АДРЕС = os.environ.get('KREST_BIND', '127.0.0.1')
ИСТОЧНИКИ = КОРЕНЬ / 'источники'
замок = threading.Lock()


def читать(файл, ключ):
    p = ИСТОЧНИКИ / файл
    if p.exists():
        try: return json.loads(p.read_text()).get(ключ, [])
        except Exception: return []
    return []


def писать(файл, ключ, строки):
    ИСТОЧНИКИ.mkdir(parents=True, exist_ok=True, mode=0o700)
    p = ИСТОЧНИКИ / файл
    tmp = p.with_suffix('.tmp')
    tmp.write_text(json.dumps({"обновлено": datetime.datetime.now().isoformat(timespec='minutes'), ключ: строки},
                              ensure_ascii=False, indent=1))
    os.chmod(tmp, 0o600)
    os.replace(tmp, p)


def checkin_date(value):
    if not isinstance(value, str) or len(value) > 48: raise ValueError('Invalid timestamp')
    stamp = datetime.datetime.fromisoformat(value.replace('Z', '+00:00'))
    if stamp.tzinfo is None: raise ValueError('Timestamp needs timezone')
    return stamp.astimezone(datetime.timezone.utc)


def clean_checkin(body, *, recorded=None):
    if not isinstance(body, dict) or not isinstance(body.get('occurrence'), str) or not re.fullmatch('[A-Za-z0-9_.:-]{1,160}', body['occurrence']):
        raise ValueError('Invalid occurrence')
    for key in ('feeling', 'energy'):
        if type(body.get(key)) is not int or not -2 <= body[key] <= 2: raise ValueError('Invalid rating')
    start, end = checkin_date(body['start']), checkin_date(body['end'])
    note = body.get('reframe', '')
    if end <= start or not isinstance(note, str) or len(note) > 280: raise ValueError('Invalid check-in')
    stamp = checkin_date(body['recorded']) if body.get('recorded') is not None else recorded
    if stamp is None: raise ValueError('Missing recorded timestamp')
    if stamp > datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(minutes=5): raise ValueError('Clock is ahead')
    return {'occurrence': body['occurrence'], 'start': start.isoformat(), 'end': end.isoformat(),
            'recorded': stamp.isoformat(), 'feeling': body['feeling'], 'energy': body['energy'], 'reframe': note}


def stored_checkins():
    """A corrupt journal is preserved, never silently replaced with an empty one."""
    path = ИСТОЧНИКИ / 'check-ins.local.json'
    if not path.exists(): return []
    rows = json.loads(path.read_text())['checkins']
    if not isinstance(rows, list) or len(rows) > 5000: raise ValueError('Invalid stored journal')
    return [clean_checkin(row) for row in rows]


def merge_checkins(existing, incoming):
    merged = {row['occurrence']: row for row in existing}
    for row in incoming:
        previous = merged.get(row['occurrence'])
        if previous is None or checkin_date(row['recorded']) > checkin_date(previous['recorded']):
            merged[row['occurrence']] = row
    return sorted(merged.values(), key=lambda row: (row['recorded'], row['occurrence']), reverse=True)[:5000]


def checkin_revision(rows):
    return hashlib.sha256(json.dumps(rows, sort_keys=True, ensure_ascii=False, separators=(',', ':')).encode()).hexdigest()


class Рук(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *a, **kw): super().__init__(*a, directory=str(КОРЕНЬ), **kw)

    def end_headers(self):
        self.send_header('Cache-Control', 'no-store, max-age=0')
        self.send_header('Referrer-Policy', 'no-referrer')
        self.send_header('X-Content-Type-Options', 'nosniff')
        super().end_headers()

    def html(self, source, base='/'):
        text = re.sub(r'<meta\b[^>]*http-equiv=["\']refresh["\'][^>]*>', '', source, flags=re.I)
        text = text.replace('<head>', '<head><base href="' + base + '">', 1)
        data = text.encode()
        self.send_response(200); self.send_header('Content-Type', 'text/html; charset=utf-8')
        self.send_header('Content-Length', str(len(data))); self.end_headers()
        if self.command != 'HEAD': self.wfile.write(data)

    def workspace_route(self, path):
        if path in ('/', '/index.html'):
            workspace = КОРЕНЬ / 'workspace.html'
            base = '/'
            if not workspace.exists():
                workspace = КОРЕНЬ / 'движок/workspace.html'
                base = urllib.parse.quote('/движок/')
            if workspace.exists(): self.html(workspace.read_text(), base); return True
        if path in ('/classic', '/classic/'):
            self.html('''<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Krest · classic instrument</title><style>html,body{margin:0;height:100%;background:#fff;color:#202124;font:13px/1.5 ui-monospace,monospace}header{height:48px;box-sizing:border-box;padding:12px 18px;display:flex;gap:20px;border-bottom:1px solid #e8e9ed}a{color:inherit}span{color:#6b6e75}iframe{border:0;width:100%;height:calc(100% - 48px)}</style></head><body><header><a href="/#research">← current research board</a><span>Classic instrument · historical model and controls · same private sources</span></header><iframe title="Classic Krest research instrument" src="/classic-frame"></iframe></body></html>'''); return True
        if path == '/classic-frame':
            legacy = КОРЕНЬ / 'index.html'
            base = '/'
            if not legacy.exists(): legacy = КОРЕНЬ / 'движок/index.html'; base = urllib.parse.quote('/движок/')
            if legacy.exists(): self.html(legacy.read_text(), base); return True
        return False

    def do_HEAD(self):
        if self.workspace_route(urllib.parse.unquote(urllib.parse.urlsplit(self.path).path)): return
        super().do_HEAD()

    def do_GET(self):
        путь = urllib.parse.urlparse(self.path)
        if self.workspace_route(urllib.parse.unquote(путь.path)): return
        if urllib.parse.unquote(путь.path) == '/контекст.json' and not (КОРЕНЬ/'контекст.json').exists():self.path='/день.json'
        if путь.path == '/check-ins':
            try:
                with замок: rows = stored_checkins()
                return self.ответ(200, rows)
            except (ValueError, KeyError, OSError): return self.ответ(503, {'error': 'Check-in journal unreadable; original preserved'})
        if путь.path.rstrip('/') in ('/отклик', '/%D0%BE%D1%82%D0%BA%D0%BB%D0%B8%D0%BA'):
            self.path = '/отклик.html' + ('?' + путь.query if путь.query else '')
        return super().do_GET()

    def do_POST(self):
        host=urllib.parse.urlsplit('//'+self.headers.get('Host','')).hostname or ''
        if host not in ('localhost','127.0.0.1','::1') and not host.endswith('.ts.net') and host not in os.environ.get('KREST_ALLOWED_HOSTS','').split(','):
            return self.ответ(403,{"error":"Host is not enabled for this private board"})
        origin = self.headers.get('Origin')
        if origin and urllib.parse.urlparse(origin).netloc != self.headers.get('Host'):
            return self.ответ(403, {"error":"Origin does not match this private board"})
        if not self.headers.get('Content-Type','').startswith('application/json'):
            return self.ответ(415, {"error":"application/json required"})
        путь = urllib.parse.urlparse(self.path).path.rstrip('/')
        путь = urllib.parse.unquote(путь)
        try: длина = int(self.headers.get('Content-Length') or 0)
        except ValueError: return self.ответ(400,{"error":"Invalid content length"})
        limit = 8_000_000 if путь == '/check-ins/sync' else 1_000_000
        if not 0 < длина <= limit: return self.ответ(413,{"error":"Payload too large or empty"})
        try: тело = json.loads(self.rfile.read(длина) or b'{}')
        except Exception: return self.ответ(400, {"ошибка": "не json"})
        try:
            with замок:
                if путь == '/calendar-snapshot': return self.ответ(200, self.calendar_snapshot(тело))
                if путь == '/check-in': return self.ответ(200, self.check_in(тело))
                if путь == '/check-ins/sync': return self.ответ(200, self.sync_checkins(тело))
                if путь == '/правка': return self.ответ(200, self.правка(тело))
                if путь == '/отклик': return self.ответ(200, self.отклик(тело))
        except (ValueError,TypeError,KeyError):
            return self.ответ(400,{"error":"Invalid input"})
        except Exception as ex:
            return self.ответ(500, {"ошибка": f"{type(ex).__name__}: {ex}"})
        self.ответ(404, {"ошибка": "нет такого"})

    def calendar_snapshot(self, body):
        if body.get('schemaVersion') != 1 or body.get('source') != 'krest-calendar-bridge': raise ValueError()
        now=datetime.datetime.now(datetime.timezone.utc)
        stamp=datetime.datetime.fromisoformat(body['fetchedAt'].replace('Z','+00:00'))
        start=datetime.datetime.fromisoformat(body['rangeStart'].replace('Z','+00:00'))
        end=datetime.datetime.fromisoformat(body['rangeEnd'].replace('Z','+00:00'))
        if abs((now-stamp).total_seconds())>min(3600,max(60,float(body.get('maxAgeSeconds',3600)))) or end<=start or not isinstance(body.get('events'),list) or len(body['events'])>4000: raise ValueError()
        events=[]
        for event in body['events']:
            a=datetime.datetime.fromisoformat(event['start'].replace('Z','+00:00'));b=datetime.datetime.fromisoformat(event['end'].replace('Z','+00:00'))
            if b<=a or not isinstance(event.get('title'),str) or len(event['title'])>1000 or not re.fullmatch('[a-f0-9]{64}',event.get('id','')):raise ValueError()
            events.append({key:event[key] for key in ('id','title','start','end','allDay','owner_response') if key in event})
        clean={key:body[key] for key in ('schemaVersion','source','fetchedAt','rangeStart','rangeEnd')};clean['events']=events
        clean['maxAgeSeconds']=min(3600,max(60,float(body.get('maxAgeSeconds',3600))))
        target=ИСТОЧНИКИ/'calendar-control.json';tmp=target.with_suffix('.tmp')
        tmp.write_text(json.dumps(clean,ensure_ascii=False));os.chmod(tmp,0o600);os.replace(tmp,target)
        self.refresh_calendar()
        return {"ok":True,"events":len(events),"captured":clean['fetchedAt']}

    def refresh_calendar(self):
        """Update only the calendar lane. No model, connector, message or scheduler."""
        context=КОРЕНЬ/('контекст.json' if (КОРЕНЬ/'контекст.json').exists() else 'день.json')
        if not context.exists():return
        sys.path.insert(0,str(КОРЕНЬ)) if str(КОРЕНЬ) not in sys.path else None
        module='адаптеры.calendar_bridge' if (КОРЕНЬ/'адаптеры/calendar_bridge.py').exists() else 'адаптеры.календарь'
        rules=json.loads((КОРЕНЬ/'правила.json').read_text());data=json.loads(context.read_text())
        now=datetime.datetime.now().astimezone();result=importlib.import_module(module).собрать(rules,now)
        for arm in data['лучи'].values():
            arm['элементы']=[e for e in arm['элементы'] if e.get('источник') not in ('календарь','звонки-живые') and e.get('id')!='r-free' and e.get('id')!='calendar-free']
        for item in result['элементы']:
            item=dict(item);item['вес_база']=item['вес']
            scale=rules['источники'].get(item['источник'],{}).get('масштаб',1);decay=item_decay(item,rules,now)
            adapter_evidence(item,'календарь',now,result.get('capturedAt'))
            weight_evidence(item,item['вес'],scale,decay)
            item['вес']=round(item['вес']*scale*decay,2)
            item.setdefault('природа','держит' if item['луч']=='ресурсы' or item.get('знак')=='+' else 'тянет')
            data['лучи'][item['луч']]['элементы'].append(item)
        for arm in data['лучи'].values():arm['сумма']=round(sum(e['вес'] for e in arm['элементы']),1);arm['штук']=len(arm['элементы'])
        total=max(1,sum(abs(arm['сумма']) for arm in data['лучи'].values())/2)
        sums={k:v['сумма'] for k,v in data['лучи'].items()}
        data['баланс']={'x':max(-1,min(1,round((sums['будущее']-sums['прошлое'])/total,2))),'y':max(-1,min(1,round((sums['ресурсы']-sums['обязательства'])/total,2)))}
        data['день']=result['события'];data.setdefault('полная_сборка',data.get('собрано'))
        data['собрано']=now.isoformat();data['дата']=now.date().isoformat()
        data['lastPartialUpdate']={'source':'календарь','checkedAt':now.isoformat()}
        data['источники']['календарь']=receipt(result,now,0)
        data['правила_версия']='2026-10-19 v5'
        atomic_json(context,data)

    def check_in(self, body):
        clean = clean_checkin(body, recorded=datetime.datetime.now(datetime.timezone.utc))
        records = merge_checkins(stored_checkins(), [clean])
        писать('check-ins.local.json', 'checkins', records)
        entry = next(row for row in records if row['occurrence'] == clean['occurrence'])
        return {'ok': True, 'entry': entry, 'revision': checkin_revision(records)}

    def sync_checkins(self, body):
        incoming = body.get('entries') if isinstance(body, dict) else None
        if not isinstance(incoming, list) or len(incoming) > 5000: raise ValueError('Invalid batch')
        clean = [clean_checkin(row) for row in incoming]
        existing = stored_checkins()
        records = merge_checkins(existing, clean)
        if records != existing: писать('check-ins.local.json', 'checkins', records)
        return {'ok': True, 'entries': records, 'revision': checkin_revision(records)}

    def правка(self, т):
        if not т.get('id'): raise ValueError('нет id')
        строки = [s for s in читать('правки.json', 'правки') if s['id'] != т['id']]
        if т.get('снять'):
            писать('правки.json', 'правки', строки); return {"ок": True, "снято": т['id']}
        з = {"id": т['id'], "когда": datetime.datetime.now().isoformat(timespec='minutes')}
        for k in ('луч', 'вес', 'перевёрнут', 'т'):
            if т.get(k) is not None: з[k] = т[k]
        строки.insert(0, з); писать('правки.json', 'правки', строки[:300])
        return {"ок": True, "правка": з}

    def отклик(self, т):
        текст = (т.get('текст') or '').strip()
        if not текст: raise ValueError('пустой отклик')
        n = datetime.datetime.now()
        o = {"id": "о-" + n.strftime('%m%d%H%M%S'), "т": текст[:70], "вес": float(т.get('вес') or 2),
             "луч": т.get('луч') or 'прошлое', "охват": "недельное", "источник": "отклики",
             "флип": "это я сам заметил и назвал; названное больше не работает вслепую",
             "т_ч": 1 if (т.get('луч') or 'прошлое') == 'прошлое' else 24 * 7,
             "факт": (f"отклик на «{т.get('событие')}» · " if т.get('событие') else "") + f"сказано {n:%d.%m %H:%M}",
             "путь": "кнопка в боте", "событие": т.get('событие')}
        строки = читать('отклики.json', 'отклики'); строки.insert(0, o)
        писать('отклики.json', 'отклики', строки[:200])
        return {"ок": True, "отклик": o}

    def ответ(self, код, тело):
        b = json.dumps(тело, ensure_ascii=False).encode()
        self.send_response(код); self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Content-Length', str(len(b))); self.end_headers(); self.wfile.write(b)

    def log_message(self, f, *a):
        s = f % a
        # Event titles, reflection query strings and request bodies never enter logs.
        if self.command != 'GET' or '?' not in self.path:
            if '/контекст' not in s: sys.stderr.write(s + "\n")


class Сервер(socketserver.ThreadingTCPServer):
    allow_reuse_address = True; daemon_threads = True


if __name__ == '__main__':
    with Сервер((АДРЕС, ПОРТ), Рук) as s:
        print(f'крест: {АДРЕС}:{ПОРТ} → {КОРЕНЬ}', flush=True)
        s.serve_forever()
