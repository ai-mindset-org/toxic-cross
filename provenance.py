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
