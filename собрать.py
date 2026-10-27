#!/usr/bin/env python3
"""Сборка дня: адаптеры → правила весов и времени → день.json (+ .js, + история/ДАТА.json).
Положение блока на луче задаёт ВРЕМЯ (т_ч, часы от сейчас), размер — вес, толщина — охват.
Запуск: python3 собрать.py [--без tg,linear,...] [--дата 2026-09-15]."""
import json, os, sys, math, datetime as dt, pathlib, importlib, zoneinfo, argparse
from provenance import adapter_evidence, manual_evidence, weight_evidence, receipt, atomic_json, atomic_text, calendar_adapter, collection_timezone, read_overrides, apply_override, prepare_weight, enrich_item
from board_state import board_key, write_board
from commitment_links import consolidate_commitments
H = pathlib.Path(__file__).parent; sys.path.insert(0, str(H))
# Пояс берётся из окружения, иначе местный: у инструмента нет своей географии.
TZ = collection_timezone(H)
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
АДАПТЕРЫ = [calendar_adapter(H), 'задачи_json', 'отклики']
статусы = {}; авто = []; события_авто = []; факты = []; наложения = {}
for имя in АДАПТЕРЫ:
    t0 = dt.datetime.now()
    source_key = {'календарь_ics': 'календарь', 'calendar_bridge': 'календарь', 'задачи_json': 'задачи'}.get(имя, имя)
    if имя in выкл or not правила['источники'].get(source_key, {}).get('enabled', True):
        статусы[имя] = {"статус": "off", "заметка": "выключен флагом", "когда": None}; continue
    try:
        m = importlib.import_module(f'адаптеры.{имя}'); r = m.собрать(правила, сейчас)
    except Exception as ex:
        r = {"статус": "dead", "элементы": [], "события": [], "заметка": f"{type(ex).__name__}: {str(ex)[:60]}"}
    статусы[имя] = receipt(r, сейчас, int((dt.datetime.now() - t0).total_seconds() * 1000))
    for item in r['элементы']: adapter_evidence(item, имя, сейчас, r.get('capturedAt'))
    авто += r['элементы']; события_авто += r.get('события', []); факты += r.get('факты', [])
    if r.get('наложения'): наложения.update(r['наложения'])

ГОР = правила['время']['горизонт_по_умолчанию_часов']

лучи = {л: {"подпись": v['подпись'], "горизонт_ч": ГОР.get(л, 720), "элементы": []} for л, v in правила['лучи'].items()}
seen = {}
for e in авто:
    prepare_weight(e, правила, сейчас)
    seen[board_key(e)] = e
for л, blk in ручное['лучи'].items():
    for e in blk['элементы']:
        e = dict(e); e.setdefault('охват', 'глобальное'); e['луч'] = л
        e['источник'] = e.get('источник') or 'ручное'; e['вес_база'] = e['вес']
        e.setdefault('факт', 'поставлено рукой: ' + e.get('источник', ''))
        e.setdefault('путь', 'источники/ручное.json')
        if not правила['источники'].get(e['источник'], {}).get('enabled', True): continue
        manual_evidence(e)
        if правила.get('configurator', {}).get('version') == 1: prepare_weight(e, правила, сейчас)
        else: weight_evidence(e, e['вес'])
        seen[board_key(e)] = e
наложения.update(read_overrides(H))
for e in seen.values():
    apply_override(e, наложения.get(e['id']))
linked_rows, _ = consolidate_commitments(list(seen.values()))
for e in linked_rows:
    enrich_item(e, правила, сейчас)
    лучи[e['луч']]['элементы'].append(e)
for л in лучи:
    лучи[л]['элементы'].sort(key=lambda e: (e['поз'], -abs(e['вес'])))
    лучи[л]['сумма'] = round(sum(e['вес'] for e in лучи[л]['элементы']), 1)
    лучи[л]['штук'] = len(лучи[л]['элементы'])

день = sorted(события_авто + [s for s in ручное.get('день', []) if a.дата], key=lambda s: s['t'])
факты = sorted(факты, key=lambda f: f.get('t') or '')
сигнал = лучи['обязательства']['сумма'] > правила.get('сигнал', {}).get('множитель', 3) * max(1, лучи['ресурсы']['сумма'])
всего = max(1, sum(abs(v['сумма']) for v in лучи.values()) / 2)
out = {"дата": сейчас.strftime('%Y-%m-%d'), "собрано": сейчас.isoformat(timespec='minutes'),
       "fictional": _ручное.name == 'ручное.json' and not os.environ.get('KREST_ICS') and not (H/'источники/calendar-control.json').exists() and not (H/'источники/задачи.local.json').exists(),
       "человек": ручное.get('человек', 'образец'), "лучи": лучи, "день": день, "факты": факты,
       "источники": статусы, "правила_версия": правила.get("версия", "открытая v1"), "сигнал": сигнал,
       "сигнал_множитель": правила.get("сигнал", {}).get("множитель", 3),
       "configurator": правила.get("configurator"),
       "переворот": правила['переворот'], "охваты": правила['охваты'],
       "баланс": {"x": max(-1,min(1,round((лучи['будущее']['сумма'] - лучи['прошлое']['сумма']) / всего, 2))),
                  "y": max(-1,min(1,round(-(лучи['обязательства']['сумма'] - лучи['ресурсы']['сумма']) / всего, 2)))}}
out = write_board(H, out, H / 'день.json', H / 'день.js')
(H / 'история').mkdir(exist_ok=True)
json.dump(out, open(H / 'история' / f"{out['дата']}.json", 'w', encoding='utf-8'), ensure_ascii=False)
print('день.json: блоков', sum(v['штук'] for v in лучи.values()),
      '· лучи', {k: v['сумма'] for k, v in лучи.items()}, '· баланс', out['баланс'])
print({k: v['статус'] for k, v in статусы.items()})
