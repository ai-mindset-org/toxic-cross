"""Private, reversible board projection and bounded observation journal.

Only this board's projection is changed. Upstream sources are never written.
The source snapshot retains hidden records across full and partial collections.
"""
from contextlib import contextmanager
from copy import deepcopy
import datetime as dt
import fcntl
import hashlib
import json
import math
import os
from pathlib import Path
import re
from provenance import atomic_json, atomic_text

MAX_RECORDS = 20000
MAX_CHANGES = 600
MAX_BYTES = 32_000_000
ARMS = ('обязательства', 'будущее', 'ресурсы', 'прошлое')


class StateUnreadable(ValueError):
    pass


def stamp():
    return dt.datetime.now(dt.timezone.utc).isoformat(timespec='microseconds')


def digest(value):
    return hashlib.sha256(json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(',', ':'), allow_nan=False).encode()).hexdigest()


def board_key(item):
    evidence = item.get('evidence') or {}
    identity = [evidence.get('kind', 'legacy'), evidence.get('adapter'), item.get('источник'),
                item.get('id'), item.get('occurrence', item.get('reviewID')), item.get('start')]
    if not item.get('id'):
        identity += [item.get('путь'), item.get('когда'), item.get('т')]
    return 'bk-' + digest(identity)


def records(context):
    result = {}
    if not isinstance(context, dict) or not isinstance(context.get('лучи'), dict): raise ValueError('Invalid context')
    for arm, group in context['лучи'].items():
        if arm not in ARMS or not isinstance(group, dict) or not isinstance(group.get('элементы'), list): raise ValueError('Invalid arm')
        for original in group['элементы']:
            item = deepcopy(original)
            if not isinstance(item, dict) or isinstance(item.get('вес'), bool) or not isinstance(item.get('вес'), (float, int)) or not math.isfinite(item['вес']): raise ValueError('Invalid weight')
            if not isinstance(item.get('evidence', {}), dict): raise ValueError('Invalid evidence')
            if not isinstance(item.get('evidence', {}).get('weight', {}), dict): raise ValueError('Invalid weight evidence')
            item['луч'] = arm
            item['boardKey'] = board_key(item)
            if item['boardKey'] in result: raise ValueError('Duplicate board identity')
            result[item['boardKey']] = item
    if len(result) > MAX_RECORDS: raise ValueError('Too many board records')
    return result


def legacy_identity(item):
    return [item.get('источник'), item.get('id'), item.get('occurrence', item.get('reviewID')), item.get('start')]


def rebalance(context):
    for group in context['лучи'].values():
        group['сумма'] = round(sum(item['вес'] for item in group['элементы']), 1)
        group['штук'] = len(group['элементы'])
    sums = {arm: context['лучи'].get(arm, {}).get('сумма', 0) for arm in ARMS}
    total = max(1, sum(abs(value) for value in sums.values()) / 2)
    context['баланс'] = {'x': max(-1, min(1, round((sums['будущее'] - sums['прошлое']) / total, 2))),
                        'y': max(-1, min(1, round((sums['ресурсы'] - sums['обязательства']) / total, 2)))}
    context['сигнал'] = sums['обязательства'] > context.get('сигнал_множитель', 3) * max(1, sums['ресурсы'])
    return context


def calendar_fingerprint(context):
    rows = [{key: event.get(key) for key in ('id', 'reviewID', 'title', 'что', 'start', 'end', 't', 'конец')}
            for event in context.get('день', [])]
    return sorted(rows, key=digest)


def semantic(item, calendar_clock=False):
    # Observation/check time, distance and decay change without an upstream edit.
    ignored = {'boardKey', 'поз', 'ч', 'т_ч', 'просрочено', 'срочно', 'вес', 'evidence', 'толщина'}
    if calendar_clock: ignored.add('вес_база')
    value = {k: v for k, v in item.items() if k not in ignored}
    if isinstance(value.get('т'), str): value['т'] = re.sub(r' · просрочено \d+ д$', '', value['т'])
    if not value.get('исключён_сегодня'): value.pop('исключён_сегодня', None)
    evidence = item.get('evidence', {})
    weight = evidence.get('weight', {})
    basis_keys = ('override',) if calendar_clock else ('base', 'override')
    value['weightBasis'] = {key: weight.get(key) for key in basis_keys}
    if evidence.get('kind') == 'manual' and evidence.get('time', {}).get('basis') == 'source-offset': value['sourceOffsetHours'] = item.get('т_ч')
    return value


def comparable(item, calendar_clock=False):
    return [semantic(item, calendar_clock), item.get('вес')]


class BoardStore:
    def __init__(self, root):
        self.root = Path(root)
        self.path = self.root / 'источники/board-state.local.json'

    @contextmanager
    def locked(self):
        self.path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
        # Directory flock avoids an extra lock file and works across collector/server processes.
        fd = os.open(self.path.parent, os.O_RDONLY)
        try:
            fcntl.flock(fd, fcntl.LOCK_EX)
            yield self
        finally:
            fcntl.flock(fd, fcntl.LOCK_UN)
            os.close(fd)

    def load(self):
        if not self.path.exists():
            return {'version': 1, 'revision': 0, 'updatedAt': None, 'hidden': {}, 'changes': [], 'snapshot': None}
        try:
            if self.path.stat().st_size > MAX_BYTES: raise ValueError()
            value = json.loads(self.path.read_text())
            if type(value['version']) is not int or value['version'] != 1 or type(value['revision']) is not int or value['revision'] < 0 or not isinstance(value['hidden'], dict) or not isinstance(value['changes'], list): raise ValueError()
            if len(value['hidden']) > MAX_RECORDS or len(value['changes']) > MAX_CHANGES: raise ValueError()
            aliases = value.get('aliases', {})
            if not isinstance(aliases, dict) or len(aliases) > MAX_RECORDS: raise ValueError()
            if any(not isinstance(key, str) or not isinstance(target, str) or not re.fullmatch(r'bk-[a-f0-9]{64}', key) or not re.fullmatch(r'bk-[a-f0-9]{64}', target) for key, target in aliases.items()): raise ValueError()
            if value.get('snapshot') is not None: records(value['snapshot'])
            for key, hidden in value['hidden'].items():
                if not re.fullmatch(r'bk-[a-f0-9]{64}', key) or not isinstance(hidden, dict) or not isinstance(hidden.get('record'), dict) or not isinstance(hidden.get('hiddenAt'), str): raise ValueError()
                row = hidden['record']
                if row.get('луч') not in ARMS or board_key(row) != key: raise ValueError()
                records({'лучи': {row['луч']: {'элементы': [row]}}})
            for event in value['changes']:
                if not isinstance(event, dict) or type(event.get('id')) is not int or event.get('kind') not in ('added', 'changed', 'removed', 'hidden', 'restored', 'recalculated'): raise ValueError()
            return value
        except (ValueError, TypeError, KeyError, OSError) as error:
            raise StateUnreadable('Board state unreadable; original preserved') from error

    def save(self, state):
        self.path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
        if len(json.dumps(state, ensure_ascii=False).encode()) > MAX_BYTES: raise ValueError('Board state capacity reached')
        encoded = json.dumps(state, ensure_ascii=False, indent=1, allow_nan=False)
        if self.path.exists() and self.path.read_text() == encoded: return
        atomic_text(self.path, encoded)

    def source(self, context, state=None):
        state = self.load() if state is None else state
        # A projection must never become a new, incomplete upstream snapshot.
        if context.get('boardState', {}).get('projection') and state.get('snapshot') is not None:
            return deepcopy(state['snapshot'])
        value = deepcopy(context)
        value.pop('boardState', None)
        return value

    def event(self, state, kind, key, before=None, after=None, cause='source'):
        record = after or before
        weight_before = before['вес'] if before else 0
        weight_after = after['вес'] if after else 0
        state['revision'] += 1
        event = {'id': state['revision'], 'at': stamp(), 'kind': kind, 'cause': cause, 'key': key,
                 'record': deepcopy(record), 'before': deepcopy(before), 'after': deepcopy(after),
                 'weightBefore': weight_before, 'weightAfter': weight_after,
                 'weightDelta': round(weight_after - weight_before, 4), 'source': record.get('источник'),
                 'arm': record['луч'], 'beforeArm': before.get('луч') if before else None}
        state['changes'].insert(0, event)
        del state['changes'][MAX_CHANGES:]
        state['updatedAt'] = event['at']

    def ingest(self, context, state=None):
        state = self.load() if state is None else state
        context = self.source(context, state)
        incoming = records(context)
        previous = records(state['snapshot']) if state.get('snapshot') is not None else {}
        # One-time provenance enrichment of legacy deployments must retain a hide.
        # Only an unambiguous legacy namespace can migrate to explicit provenance.
        aliases = state.setdefault('aliases', {})
        for old_key, old in previous.items():
            if old_key in incoming or old.get('evidence'): continue
            matches = [key for key, row in incoming.items() if legacy_identity(row) == legacy_identity(old)]
            legacy_matches = [row for row in previous.values() if legacy_identity(row) == legacy_identity(old)]
            if len(matches) == len(legacy_matches) == 1:
                new_key = matches[0]
                aliases[old_key] = new_key
                if old_key in state['hidden']:
                    state['hidden'][new_key] = state['hidden'].pop(old_key)
        if len(aliases) > MAX_RECORDS: raise ValueError('Board alias capacity reached')
        calendar_same = state.get('snapshot') is not None and calendar_fingerprint(context) == calendar_fingerprint(state['snapshot'])
        for key in sorted(set(previous) | set(incoming)):
            before, after = previous.get(key), incoming.get(key)
            clock_calendar = calendar_same and (after or before).get('источник') in ('календарь', 'звонки-живые', 'ресурсы-авто')
            if before and after and comparable(before,clock_calendar) == comparable(after,clock_calendar): continue
            cause = 'recalculation' if clock_calendar or (before and after and semantic(before) == semantic(after)) else 'source'
            kind = 'added' if before is None else 'removed' if after is None else 'recalculated' if cause == 'recalculation' else 'changed'
            self.event(state, kind, key, before, after, cause)
        # Store the complete latest records, including records currently hidden.
        for arm, group in context['лучи'].items():
            group['элементы'] = [incoming[board_key(item)] for item in group['элементы']]
        state['snapshot'] = context
        for key, hidden in state['hidden'].items():
            if key in incoming: hidden['record'] = deepcopy(incoming[key])
        self.save(state)
        return state

    def projection(self, state):
        context = deepcopy(state['snapshot'])
        if context is None: raise ValueError('No context available')
        for group in context['лучи'].values():
            group['элементы'] = [item for item in group['элементы'] if item['boardKey'] not in state['hidden']]
        rebalance(context)
        if isinstance(context.get('promiseRegistry'), dict):
            from promise_projection import annotate_influence
            active = [item for group in context['лучи'].values() for item in group['элементы']]
            hidden = [value['record'] for value in state['hidden'].values()]
            context['promiseRegistry'] = annotate_influence(context['promiseRegistry'], active, hidden)
        context['boardState'] = {'projection': True, 'revision': state['revision'],
                                  'hiddenCount': len(state['hidden']), 'updatedAt': state['updatedAt'],
                                  'sourceCollectedAt': context.get('собрано'), 'changeLimit': MAX_CHANGES}
        return context

    def public(self, state):
        current = records(state['snapshot']) if state.get('snapshot') else {}
        return {'revision': state['revision'], 'updatedAt': state['updatedAt'],
                'hidden': [{'key': key, **deepcopy(value), 'present': key in current} for key, value in state['hidden'].items()],
                'changes': deepcopy(state['changes']), 'changeLimit': MAX_CHANGES,
                'sourceCollectedAt': (state.get('snapshot') or {}).get('собрано')}

    def visibility(self, context, key, hidden):
        if not isinstance(key, str) or not re.fullmatch(r'bk-[a-f0-9]{64}', key) or type(hidden) is not bool: raise ValueError('Invalid visibility')
        state = self.ingest(context)
        current = records(state['snapshot'])
        key = state.get('aliases', {}).get(key, key)
        if key not in current and key not in state['hidden']: raise KeyError('Unknown board record')
        old = state['hidden'].get(key)
        if hidden and old is None:
            state['hidden'][key] = {'record': deepcopy(current[key]), 'hiddenAt': stamp()}
            self.event(state, 'hidden', key, current[key], None, 'board')
        elif not hidden and old is not None:
            # Undo preserves the retained record; an absent upstream record stays absent.
            self.event(state, 'restored', key, None, current.get(key, old['record']), 'board')
            if key not in current:
                state['changes'][0].update(weightAfter=0, weightDelta=0, present=False)
            del state['hidden'][key]
        self.save(state)
        return {'ok': True, 'context': self.projection(state), 'state': self.public(state)}


def context_path(root):
    root = Path(root)
    return root / ('контекст.json' if (root / 'контекст.json').exists() else 'день.json')


def read_board(root, *, state_only=False):
    store = BoardStore(root)
    with store.locked():
        state = store.ingest(json.loads(context_path(root).read_text()))
        return store.public(state) if state_only else store.projection(state)


def write_board(root, context, path, javascript=None):
    store = BoardStore(root)
    with store.locked():
        state = store.ingest(context)
        active = store.projection(state)
        atomic_json(path, active)
        if javascript: atomic_text(javascript, 'window.КОНТЕКСТ=' + json.dumps(active, ensure_ascii=False) + ';')
        return active
