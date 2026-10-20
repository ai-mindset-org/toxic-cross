"""Inspectable provenance. A successful read never invents an upstream timestamp."""
import datetime as dt
import json
import os
from pathlib import Path
import tempfile


def adapter_evidence(item, adapter, observed, captured=None):
    item['evidence'] = {'kind': 'adapter', 'adapter': adapter,
                        'observedAt': observed.isoformat(), 'sourceCapturedAt': captured,
                        'weight': {}, 'time': {'basis': time_basis(item)}}
    return item


def manual_evidence(item):
    item['evidence'] = {'kind': 'manual', 'adapter': None, 'observedAt': None,
                        'sourceCapturedAt': item.get('когда'), 'weight': {}, 'time': {'basis': time_basis(item)}}
    return item


def time_basis(item):
    if item.get('т_ч') is not None: return 'source-offset'
    if item.get('когда'): return 'recorded-time'
    return 'scope-default'


def weight_evidence(item, base, scale=1, decay=1, override=None):
    item.setdefault('evidence', {})['weight'] = {'base': base, 'scale': scale,
                                                'decay': decay, 'override': override}


def item_decay(item, rules, now):
    half_life = rules['охваты'].get(item.get('охват', 'недельное'), rules['охваты']['недельное'])['полураспад_дней']
    stamp = item.get('когда')
    if item.get('т_ч') is not None and not stamp:
        days = max(0, abs(item['т_ч']) / 24) if item['луч'] == 'прошлое' else 0
    elif stamp:
        try:
            value = dt.datetime.fromisoformat(str(stamp).replace('Z', '+00:00'))
            if value.tzinfo is None: value = value.replace(tzinfo=now.tzinfo)
            days = max(0, (now - value).total_seconds() / 86400)
        except (ValueError, TypeError): return 1
    else: days = 0
    return 0.5 ** (days / half_life) if days else 1


def receipt(result, observed, elapsed):
    value = {'статус': result['статус'], 'заметка': result.get('заметка', ''),
             'когда': observed.isoformat(), 'checkedAt': observed.isoformat(),
             'capturedAt': result.get('capturedAt'), 'мс': elapsed}
    if result.get('expiresAt'): value['expiresAt'] = result['expiresAt']
    return value


def atomic_text(path, text):
    path = Path(path)
    handle = tempfile.NamedTemporaryFile(mode='w', encoding='utf-8', dir=path.parent,
                                         prefix='.' + path.name + '-', suffix='.tmp', delete=False)
    try:
        with handle:
            os.fchmod(handle.fileno(), 0o600)
            handle.write(text)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(handle.name, path)
    finally:
        if os.path.exists(handle.name): os.unlink(handle.name)


def atomic_json(path, value):
    atomic_text(path, json.dumps(value, ensure_ascii=False, indent=1))


def calendar_adapter(root):
    """Full and partial collection use the same installed calendar model."""
    root = Path(root)
    if (root / 'адаптеры/календарь.py').exists(): return 'календарь'
    if (root / 'источники/calendar-control.json').exists(): return 'calendar_bridge'
    return 'календарь_ics'


def collection_timezone(root):
    import zoneinfo
    name = os.environ.get('KREST_TZ')
    if not name and (Path(root) / 'адаптеры/календарь.py').exists(): name = 'Europe/Lisbon'
    return zoneinfo.ZoneInfo(name) if name else dt.datetime.now().astimezone().tzinfo


def read_overrides(root):
    path = Path(root) / 'источники/правки.json'
    if not path.exists(): return {}
    rows = json.loads(path.read_text()).get('правки', [])
    if not isinstance(rows, list): raise ValueError('Invalid board overrides')
    # The journal is newest-first, just like the private правки adapter.
    result = {}
    for row in rows:
        if not isinstance(row, dict) or not row.get('id'): raise ValueError('Invalid board override')
        result.setdefault(row['id'], row)
    return result


def apply_override(item, override):
    if not override: return item
    for key in ('луч', 'природа', 'т'):
        if override.get(key): item[key] = override[key]
    if override.get('вес') is not None:
        value = float(override['вес'])
        item['вес_рука'] = item['вес'] = value
        item.setdefault('evidence', {}).setdefault('weight', {})['override'] = value
    if override.get('перевёрнут') is not None: item['перевёрнут'] = bool(override['перевёрнут'])
    item['правка'] = override.get('когда')
    return item


def prepare_weight(item, rules, now, adapter=None, captured=None):
    if adapter is not None: adapter_evidence(item, adapter, now, captured)
    item['вес_база'] = item['вес']
    scale = rules['источники'].get(item['источник'], {}).get('масштаб', 1)
    decay = item_decay(item, rules, now)
    weight_evidence(item, item['вес'], scale, decay)
    item['вес'] = round(item['вес'] * scale * decay, 2)
    return item


def enrich_item(item, rules, now, held_ids=()):
    """Shared deterministic rendering fields, after weights and manual overrides."""
    import math
    scope = item.setdefault('охват', 'недельное')
    if not item.get('природа'):
        if item['луч'] == 'ресурсы': item['природа'] = 'тянет' if item['вес'] < 0 else 'держит'
        else: item['природа'] = 'держит' if item.get('знак') == '+' or (item['луч'] == 'прошлое' and item['id'] in held_ids) else 'тянет'
    item['толщина'] = rules['охваты'][scope]['толщина']
    hours = item.get('т_ч')
    if hours is None and item.get('когда'):
        try:
            when = dt.datetime.fromisoformat(str(item['когда']).replace('Z', '+00:00'))
            if when.tzinfo is None: when = when.replace(tzinfo=now.tzinfo)
            hours = abs((now - when).total_seconds() / 3600)
        except (ValueError, TypeError): hours = None
    if hours is None: hours = {'ситуативное': 12, 'недельное': 120, 'глобальное': 960}[scope]
    horizon = rules.get('время', {}).get('горизонт_по_умолчанию_часов', {}).get(item['луч'], 720)
    item['ч'] = 0 if item.get('срочно') else round(abs(hours), 2)
    item['поз'] = 0.0 if item.get('срочно') else round(min(1.0, math.log10(1 + abs(hours)) / math.log10(1 + horizon)), 4)
    return item
