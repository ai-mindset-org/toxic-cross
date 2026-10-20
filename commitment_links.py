"""Explicit cross-source identity. Titles and date proximity never establish equality."""
from collections import defaultdict
from copy import deepcopy
import re

LINEAR_ID = re.compile(r'^[A-Z][A-Z0-9]*-[1-9][0-9]*$')


def source_kind(row):
    return row.get('evidence', {}).get('adapter') or row.get('источник')


def focus_linear_id(row):
    if source_kind(row) != 'фокус' or row.get('accepted') is not True: return None
    ident = row.get('focus_item_id')
    if ident is None and str(row.get('id', '')).startswith('focus-'):
        ident = row['id'][len('focus-'):]
    return ident if isinstance(ident, str) and LINEAR_ID.fullmatch(ident) else None


def consolidate_focus(rows):
    """An accepted focus naming one exact active Linear issue is linked context.

    Retain the Linear record and its declared weight, including manual overrides.
    Ambiguous IDs, unaccepted suggestions and other source kinds are untouched.
    Return remapped focus element IDs for the Overview, without changing the plan.
    """
    linear, focuses = defaultdict(list), defaultdict(list)
    for index, row in enumerate(rows):
        ident = row.get('id')
        if source_kind(row) == 'linear' and isinstance(ident, str) and LINEAR_ID.fullmatch(ident): linear[ident].append(index)
        key = focus_linear_id(row)
        if key: focuses[key].append(index)
    result = deepcopy(rows)
    omitted, aliases = set(), {}
    for ident, focus_indices in focuses.items():
        if len(linear[ident]) != 1 or len(focus_indices) != 1: continue
        at, focus_at = linear[ident][0], focus_indices[0]
        primary, focus = result[at], result[focus_at]
        primary['commitment'] = {
            'canonicalId': 'linear:' + ident,
            'policy': 'Active Linear weight counted once',
            'reason': 'The accepted focus names this exact Linear identifier. Focus is linked context and adds no second weight.',
            'inputs': [{'source': primary.get('источник', 'linear'), 'id': ident, 'weight': primary['вес'], 'representative': True},
                       {'source': focus.get('источник', 'фокус'), 'id': focus['id'], 'weight': focus['вес'], 'representative': False}],
        }
        primary['references'] = list(primary.get('references') or []) + list(focus.get('references') or [])
        omitted.add(focus_at)
        aliases[focus['id']] = primary['id']
    return [row for index, row in enumerate(result) if index not in omitted], aliases


def consolidate_commitments(rows):
    result, aliases = consolidate_focus(rows)
    targets = defaultdict(list)
    for index, row in enumerate(result):
        if source_kind(row) == 'linear' and LINEAR_ID.fullmatch(str(row.get('id', ''))): targets[row['id']].append(index)
    # An accepted focus supplies the representative only when no active Linear row exists.
    linear_ids = set(targets)
    for index, row in enumerate(result):
        ident = focus_linear_id(row)
        if ident and ident not in linear_ids: targets[ident].append(index)
    omitted = set()
    for index, row in enumerate(result):
        ident = row.get('commitment', {}).get('taskIdentity')
        if row.get('confirmation') != 'source-action-ledger' or not ident or len(targets[ident]) != 1: continue
        at = targets[ident][0]
        if at == index: continue
        primary = result[at]
        model = primary.setdefault('commitment', {'canonicalId': 'linear:' + ident, 'inputs': [
            {'source': primary.get('источник'), 'id': primary['id'], 'weight': primary['вес'], 'representative': True}]})
        model.update(policy='One task or accepted focus weight', reason='The reviewed action ledger explicitly identifies the same task. Promise and focus supply linked evidence, without additional weights.')
        model['inputs'].append({'source': row.get('источник'), 'id': row['id'], 'promiseId': row.get('promise_id'), 'weight': row['вес'], 'representative': False})
        primary['references'] = list(primary.get('references') or []) + list(row.get('references') or [])
        omitted.add(index)
    return [row for index, row in enumerate(result) if index not in omitted], aliases
