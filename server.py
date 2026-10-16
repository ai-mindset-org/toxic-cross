#!/usr/bin/env python3
"""Статика креста + маленькая запись правок. Только loopback, наружу отдаёт tailscale serve.

GET  /                     борт
GET  /отклик?...           страница ответа на вопрос пса (кнопки в боте ведут сюда)
POST /правка               {id, луч?, вес?, перевёрнут?, текст?}  → источники/правки.json
POST /отклик               {событие, луч, текст, вес}             → источники/отклики.json
"""
import http.server, socketserver, os, sys, json, pathlib, datetime, urllib.parse, threading, re, importlib, math

_here=pathlib.Path(__file__).resolve().parent
КОРЕНЬ = pathlib.Path(os.environ.get('KREST_ROOT', _here.parent if _here.name=='сервер' else _here)).resolve()
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
    p = ИСТОЧНИКИ / файл
    tmp = p.with_suffix('.tmp')
    tmp.write_text(json.dumps({"обновлено": datetime.datetime.now().isoformat(timespec='minutes'), ключ: строки},
                              ensure_ascii=False, indent=1))
    os.chmod(tmp, 0o600)
    os.replace(tmp, p)


class Рук(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *a, **kw): super().__init__(*a, directory=str(КОРЕНЬ), **kw)

    def end_headers(self):
        if self.path.split('?')[0].endswith(('.json', '.js')) or self.path.split('?')[0] in ('/check-ins','/check-in','/calendar-snapshot'):
            self.send_header('Cache-Control', 'no-store, max-age=0')
        super().end_headers()

    def do_GET(self):
        путь = urllib.parse.urlparse(self.path)
        if путь.path == '/' and not (КОРЕНЬ/'index.html').exists():
            self.send_response(302);self.send_header('Location',urllib.parse.quote('/движок/workspace.html'));self.end_headers();return
        if urllib.parse.unquote(путь.path) == '/контекст.json' and not (КОРЕНЬ/'контекст.json').exists():self.path='/день.json'
        if путь.path == '/check-ins': return self.ответ(200, читать('check-ins.local.json', 'checkins'))
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
        if not 0 < длина <= 1_000_000: return self.ответ(413,{"error":"Payload too large or empty"})
        try: тело = json.loads(self.rfile.read(длина) or b'{}')
        except Exception: return self.ответ(400, {"ошибка": "не json"})
        try:
            with замок:
                if путь == '/calendar-snapshot': return self.ответ(200, self.calendar_snapshot(тело))
                if путь == '/check-in': return self.ответ(200, self.check_in(тело))
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
            item=dict(item);item['вес_база']=item['вес'];item['вес']*=rules['источники'].get(item['источник'],{}).get('масштаб',1)
            item.setdefault('природа','держит' if item['луч']=='ресурсы' or item.get('знак')=='+' else 'тянет')
            data['лучи'][item['луч']]['элементы'].append(item)
        for arm in data['лучи'].values():arm['сумма']=round(sum(e['вес'] for e in arm['элементы']),1);arm['штук']=len(arm['элементы'])
        total=max(1,sum(abs(arm['сумма']) for arm in data['лучи'].values())/2)
        sums={k:v['сумма'] for k,v in data['лучи'].items()}
        data['баланс']={'x':max(-1,min(1,round((sums['будущее']-sums['прошлое'])/total,2))),'y':max(-1,min(1,round((sums['ресурсы']-sums['обязательства'])/total,2)))}
        data['день']=result['события'];data['собрано']=now.isoformat();data['дата']=now.date().isoformat()
        data['источники']['календарь']={'статус':result['статус'],'заметка':result['заметка'],'когда':now.isoformat()}
        if result.get('expiresAt'):data['источники']['календарь']['expiresAt']=result['expiresAt']
        data['правила_версия']='2026-10-16 v4'
        tmp=context.with_suffix('.tmp');tmp.write_text(json.dumps(data,ensure_ascii=False));os.chmod(tmp,0o600);os.replace(tmp,context)

    def check_in(self, body):
        if not re.fullmatch('[A-Za-z0-9_.:-]{1,160}',body.get('occurrence','')):raise ValueError()
        for key in ('feeling','energy'):
            if type(body.get(key)) is not int or not -2<=body[key]<=2:raise ValueError()
        start=datetime.datetime.fromisoformat(body['start'].replace('Z','+00:00'));end=datetime.datetime.fromisoformat(body['end'].replace('Z','+00:00'))
        if end<=start or not isinstance(body.get('reframe',''),str) or len(body.get('reframe',''))>280:raise ValueError()
        clean={key:body[key] for key in ('occurrence','start','end','feeling','energy')}
        clean['recorded']=datetime.datetime.now(datetime.timezone.utc).isoformat();clean['reframe']=body.get('reframe','')
        records=[clean]+[r for r in читать('check-ins.local.json','checkins') if r.get('occurrence')!=clean['occurrence']]
        писать('check-ins.local.json','checkins',records[:5000]);return {"ok":True}

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
