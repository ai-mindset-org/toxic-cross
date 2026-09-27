#!/usr/bin/env python3
"""Сборка дня: адаптеры → правила весов и времени → день.json (+ .js, + история/ДАТА.json).
Положение блока на луче задаёт ВРЕМЯ (т_ч, часы от сейчас), размер — вес, толщина — охват.
Запуск: python3 собрать.py [--без tg,linear,...] [--дата 2026-09-15]."""
import json, os, sys, math, datetime as dt, pathlib, importlib, zoneinfo, argparse
H = pathlib.Path(__file__).parent; sys.path.insert(0, str(H))
# Пояс берётся из окружения, иначе местный: у инструмента нет своей географии.
_tz = os.environ.get('KREST_TZ')
TZ = zoneinfo.ZoneInfo(_tz) if _tz else dt.datetime.now().astimezone().tzinfo
ap = argparse.ArgumentParser(); ap.add_argument('--без', default=''); ap.add_argument('--дата', default=None)
a = ap.parse_args()
сейчас = dt.datetime.now(TZ) if not a.дата else dt.datetime.fromisoformat(a.дата).replace(tzinfo=TZ, hour=23, minute=0)
правила = json.load(open(H / 'правила.json', encoding='utf-8'))
# Свой ручной слой кладётся рядом с образцом под именем *.local.json: он уже в .gitignore.
_ручное = H / 'источники/ручное.local.json'
if not _ручное.exists():
    _ручное = H / 'источники/ручное.json'
ручное = json.load(open(_ручное, encoding='utf-8'))
выкл = set(x for x in a.без.split(',') if x)
АДАПТЕРЫ = ['календарь_ics', 'задачи_json', 'отклики']
статусы = {}; авто = []; события_авто = []; факты = []; наложения = {}
for имя in АДАПТЕРЫ:
    t0 = dt.datetime.now()
    if имя in выкл:
        статусы[имя] = {"статус": "off", "заметка": "выключен флагом", "когда": None}; continue
    try:
        m = importlib.import_module(f'адаптеры.{имя}'); r = m.собрать(правила, сейчас)
    except Exception as ex:
        r = {"статус": "dead", "элементы": [], "события": [], "заметка": f"{type(ex).__name__}: {str(ex)[:60]}"}
    статусы[имя] = {"статус": r['статус'], "заметка": r.get('заметка', ''),
                    "когда": сейчас.isoformat(timespec='minutes'),
                    "мс": int((dt.datetime.now() - t0).total_seconds() * 1000)}
    авто += r['элементы']; события_авто += r.get('события', []); факты += r.get('факты', [])
    if r.get('наложения'): наложения.update(r['наложения'])

ГОР = правила['время']['горизонт_по_умолчанию_часов']

def затухание(e):
    охв = правила['охваты'].get(e.get('охват', 'недельное'), правила['охваты']['недельное'])
    hl = охв['полураспад_дней']; когда = e.get('когда')
    if e.get('т_ч') is not None and not когда:
        возраст = max(0.0, abs(e['т_ч']) / 24) if e['луч'] in ('прошлое',) else 0.0
        return 0.5 ** (возраст / hl) if возраст else 1.0
    if not когда: return 1.0
    try:
        t = dt.datetime.fromisoformat(str(когда).replace('Z', '+00:00'))
        if t.tzinfo is None: t = t.replace(tzinfo=TZ)
    except Exception:
        return 1.0
    возраст = max(0.0, (сейчас - t).total_seconds() / 86400)
    return 0.5 ** (возраст / hl)

def позиция(e):
    """0 = центр (сейчас или просрочено), 1 = край луча."""
    if e.get('срочно'): return 0.0
    ч = e.get('т_ч')
    if ч is None:
        когда = e.get('когда')
        if когда:
            try:
                t = dt.datetime.fromisoformat(str(когда).replace('Z', '+00:00'))
                if t.tzinfo is None: t = t.replace(tzinfo=TZ)
                ч = abs((сейчас - t).total_seconds() / 3600)
            except Exception: ч = None
    if ч is None: ч = {'ситуативное': 12, 'недельное': 24 * 5, 'глобальное': 24 * 40}[e.get('охват', 'недельное')]
    ч = abs(ч); гор = ГОР.get(e['луч'], 720)
    return min(1.0, math.log10(1 + ч) / math.log10(1 + гор))

лучи = {л: {"подпись": v['подпись'], "горизонт_ч": ГОР.get(л, 720), "элементы": []} for л, v in правила['лучи'].items()}
seen = {}
for e in авто:
    e['вес_база'] = e['вес']
    e['вес'] = round(e['вес'] * правила['источники'].get(e['источник'], {}).get('масштаб', 1) * затухание(e), 2)
    seen[e['id']] = e
for л, blk in ручное['лучи'].items():
    for e in blk['элементы']:
        e = dict(e); e.setdefault('охват', 'глобальное'); e['луч'] = л
        e['источник'] = e.get('источник') or 'ручное'; e['вес_база'] = e['вес']
        e.setdefault('факт', 'поставлено рукой: ' + e.get('источник', ''))
        e.setdefault('путь', 'источники/ручное.json')
        seen[e['id']] = e
for id_, н in наложения.items():                      # ручные правки поверх всего
    e = seen.get(id_)
    if not e: continue
    if н.get('луч'): e['луч'] = н['луч']
    if н.get('природа'): e['природа'] = н['природа']
    if н.get('т'): e['т'] = н['т']
    if н.get('вес') is not None: e['вес_рука'] = float(н['вес']); e['вес'] = float(н['вес'])
    if н.get('перевёрнут') is not None: e['перевёрнут'] = bool(н['перевёрнут'])
    e['правка'] = н.get('когда')
# Что в прошлом держит, а что тянет, решает знак элемента: плюс держит.
for e in seen.values():
    e.setdefault('охват', 'недельное')
    if not e.get('природа'):                      # тянет вверх или держит внизу
        if e['луч'] == 'ресурсы':
            e['природа'] = 'тянет' if e['вес'] < 0 else 'держит'
        elif e['луч'] == 'прошлое':
            e['природа'] = 'держит' if e.get('знак') == '+' else 'тянет'
        else:
            e['природа'] = 'держит' if e.get('знак') == '+' else 'тянет'
    e['толщина'] = правила['охваты'][e['охват']]['толщина']
    e['поз'] = round(позиция(e), 4)
    ч = e.get('т_ч')
    if ч is None and e.get('когда'):
        try:
            _t = dt.datetime.fromisoformat(str(e['когда']).replace('Z', '+00:00'))
            if _t.tzinfo is None: _t = _t.replace(tzinfo=TZ)
            ч = abs((сейчас - _t).total_seconds() / 3600)
        except Exception: ч = None
    if ч is None: ч = {'ситуативное': 12, 'недельное': 24 * 5, 'глобальное': 24 * 40}[e['охват']]
    e['ч'] = 0 if e.get('срочно') else round(abs(ч), 2)
    лучи[e['луч']]['элементы'].append(e)
for л in лучи:
    лучи[л]['элементы'].sort(key=lambda e: (e['поз'], -abs(e['вес'])))
    лучи[л]['сумма'] = round(sum(e['вес'] for e in лучи[л]['элементы']), 1)
    лучи[л]['штук'] = len(лучи[л]['элементы'])

день = sorted(события_авто + [s for s in ручное.get('день', []) if a.дата], key=lambda s: s['t'])
факты = sorted(факты, key=lambda f: f.get('t') or '')
сигнал = лучи['обязательства']['сумма'] > 3 * max(1, лучи['ресурсы']['сумма'])
всего = max(1, sum(v['сумма'] for v in лучи.values()) / 2)
out = {"дата": сейчас.strftime('%Y-%m-%d'), "собрано": сейчас.isoformat(timespec='minutes'),
       "человек": ручное.get('человек', 'образец'), "лучи": лучи, "день": день, "факты": факты,
       "источники": статусы, "правила_версия": правила.get("версия", "открытая v1"), "сигнал": сигнал,
       "переворот": правила['переворот'], "охваты": правила['охваты'],
       "баланс": {"x": round((лучи['будущее']['сумма'] - лучи['прошлое']['сумма']) / всего, 2),
                  "y": round(-(лучи['обязательства']['сумма'] - лучи['ресурсы']['сумма']) / всего, 2)}}
json.dump(out, open(H / 'день.json', 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
open(H / 'день.js', 'w', encoding='utf-8').write('window.КОНТЕКСТ=' + json.dumps(out, ensure_ascii=False) + ';')
(H / 'история').mkdir(exist_ok=True)
json.dump(out, open(H / 'история' / f"{out['дата']}.json", 'w', encoding='utf-8'), ensure_ascii=False)
print('день.json: блоков', sum(v['штук'] for v in лучи.values()),
      '· лучи', {k: v['сумма'] for k, v in лучи.items()}, '· баланс', out['баланс'])
print({k: v['статус'] for k, v in статусы.items()})
