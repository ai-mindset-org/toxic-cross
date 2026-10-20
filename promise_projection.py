"""Read-only owner projection. Extracted registry candidates never imply acceptance."""
from copy import deepcopy
import datetime as dt
import re
import math
from collections import Counter


def stamp(value):
    parsed = dt.datetime.fromisoformat(str(value).replace('Z', '+00:00'))
    if parsed.tzinfo is None: raise ValueError('Source timestamp needs timezone')
    return parsed


def project_promises(packet, owner_id, now, overrides=None):
    if not isinstance(packet, dict) or packet.get('schema_version') != 1 or packet.get('observed') is not True:
        raise ValueError('Unreadable promise projection')
    source_time, expires = stamp(packet['source_last_success_at']), stamp(packet['expires_at'])
    if source_time > now + dt.timedelta(minutes=5) or expires <= source_time: raise ValueError('Invalid source freshness')
    raw = packet['records']
    if not isinstance(raw, list) or len(raw) > 20000: raise ValueError('Invalid promise records')
    records, elements, seen = [], [], set()
    overrides = overrides or {}
    prefixes = Counter(str(row.get('id', ''))[:10] for row in raw if isinstance(row, dict) and row.get('owner_id') == owner_id)
    fresh = now < expires
    for original in raw:
        if not isinstance(original, dict) or type(original.get('owner_id')) is not int or original['owner_id'] != owner_id: continue
        row = deepcopy(original)
        ident = row.get('id')
        if not isinstance(ident, str) or not ident or len(ident) > 160 or ident in seen: raise ValueError('Promise identity missing or duplicated')
        seen.add(ident)
        deadline = row.get('deadline') or {'kind': 'unknown', 'label': 'Date unknown'}
        flags = row.get('flags') or []
        if not isinstance(flags, list) or not isinstance(deadline, dict): raise ValueError('Invalid promise quality metadata')
        reviewed = row.get('confirmation') == 'source-action-ledger'
        element_id = 'p-' + ident[:10] if prefixes[ident[:10]] == 1 else 'promise-' + ident
        override = overrides.get(element_id) or {}
        manual = type(override.get('вес')) in (int, float) and math.isfinite(override['вес'])
        eligible = fresh and (reviewed or manual) and row.get('status') in ('open', 'linear') and row.get('kind') in ('commitment', 'task') and not set(flags) & {'not-commitment', 'needs-owner', 'completion-claim', 'source-in-future', 'source-missing', 'linear-done-review'}
        row['influence'] = {'kind': 'candidate', 'weight': 0, 'reason': 'Registry candidate; no accepted model weight.'}
        if row.get('status') == 'closed': row['influence']['kind'] = 'closed'
        elif not fresh: row['influence']['reason'] = 'Source expired; current state requires a fresh source.'
        references = []
        if packet.get('url'): references.append({'kind': 'registry', 'label': 'Open promise registry', 'id': ident, 'url': packet['url']})
        # Source routing may be supplied independently of the repo-relative path.
        if row.get('source_url') and '#call=' not in row['source_url']:
            references.append({'kind': 'source', 'label': 'Original meeting', 'url': row['source_url']})
        for link in row.get('linear_links') or []:
            if link.get('url'): references.append({'kind': 'linear', 'label': 'Open Linear', 'id': link.get('id'), 'url': link['url']})
        row['references'] = references
        records.append(row)
        if not eligible: continue
        item = {'id': element_id, 'promise_id': ident, 'т': row.get('title') or row.get('text') or 'Reviewed commitment',
                'вес': 2, 'источник': 'обещания', 'луч': 'обязательства', 'охват': 'недельное',
                'факт': 'Reviewed source action · ' + str(row.get('source') or 'source not supplied'),
                'путь': row.get('source_ref') or '', 'references': references, 'flags': flags,
                'confirmation': row['confirmation'], 'флип': 'Check the accepted result, its owner and the next step.',
                'commitment': {'canonicalId': row.get('chain_id') or 'promise:' + ident,
                               'policy': 'User-declared weight retained' if manual and not reviewed else 'Reviewed promise counted once',
                               'reason': 'An existing manual model weight is preserved; registry acceptance and closure are unchanged.' if manual and not reviewed else 'Reviewed source action; machine extraction alone has no weight.'}}
        chain = re.fullmatch(r'task:([A-Z][A-Z0-9]*-[1-9][0-9]*)', str(row.get('chain_id', '')))
        if chain and reviewed: item['commitment']['taskIdentity'] = chain.group(1)
        if deadline.get('kind') == 'exact' and deadline.get('date'):
            date = dt.date.fromisoformat(deadline['date'])
            due = dt.datetime.combine(date, dt.time(23, 59), tzinfo=now.tzinfo)
            item.update(срок=date.isoformat(), т_ч=(due-now).total_seconds()/3600,
                        просрочено=max(0, (now.date()-date).days), срочно=date < now.date())
        elif deadline.get('kind') == 'window':
            item['dueWindow'] = deadline
        elements.append(item)
    registry = {key: deepcopy(packet.get(key)) for key in ('schema_version', 'complete', 'status', 'source', 'checked_at', 'source_last_success_at', 'expires_at', 'coverage', 'coverage_counts', 'owner_quality', 'url')}
    registry.update(records=records, owner_id=owner_id, fresh=fresh)
    return {'статус': 'live' if fresh else 'quiet', 'элементы': elements, 'события': [],
            'capturedAt': source_time.isoformat(), 'expiresAt': expires.isoformat(), 'promiseRegistry': registry,
            'заметка': f'{len(records)} owner records · {len(elements)} eligible model records before explicit dedup · candidates have no automatic weight'}


def annotate_influence(registry, rows, hidden=()):
    result = deepcopy(registry)
    by_id = {row['id']: row for row in result.get('records', [])}
    for row in by_id.values():
        row['influence'] = {'kind': 'closed' if row.get('status') == 'closed' else 'candidate', 'weight': 0,
                            'reason': 'Registry candidate; no accepted model weight.'}
    for row in rows:
        ident = row.get('promise_id')
        if ident in by_id:
            by_id[ident]['influence'] = {'kind': 'counted', 'weight': row['вес'], 'representativeId': row['id'], 'reason': row.get('commitment', {}).get('reason') or 'Reviewed promise supplies this representative weight.'}
        for part in row.get('commitment', {}).get('inputs', []):
            ident = part.get('promiseId')
            if ident in by_id:
                by_id[ident]['influence'] = {'kind': 'linked', 'weight': 0, 'representativeId': row['id'], 'representativeWeight': row['вес'], 'reason': 'Linked evidence; the existing task or accepted focus is counted once.'}
    for row in hidden:
        identities = [row.get('promise_id')] + [part.get('promiseId') for part in row.get('commitment', {}).get('inputs', [])]
        for ident in identities:
            if ident in by_id: by_id[ident]['influence'] = {'kind': 'hidden', 'weight': 0, 'representativeId': row['id'], 'reason': 'Hidden from the active board; source retained. Restore in Changes.'}
    return result
