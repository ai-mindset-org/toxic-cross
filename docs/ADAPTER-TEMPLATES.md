# Own-source adapter templates

Start with ICS, ignored manual JSON or task JSON. Each additional source needs an owner-selected read scope, minimal records and an explicit capture/expiry receipt. Read [свой-источник.md](свой-источник.md) and copy адаптеры/ОБРАЗЕЦ.py for the canonical interface. Add its module deliberately to АДАПТЕРЫ; adding a JSON key never executes a module.

For a tracker API, keep its token in a private environment file and fetch only the owner's chosen tasks with read-only credentials. Normalize them to the existing источники/задачи.local.json schema: `ключ`, `название`, `статус`, `приоритет`, `срок`, `движение`. Preserve actual dates, time zones and upstream capture time; do not include `_база` in a personal export. The built-in JSON adapter then works without an API dependency. API selection in the configurator records setup intent; the agent must implement and verify the integration separately.

Telegram counts, reviewed promises, infrastructure status and existing call observations can use the same small snapshot adapter below. Copy it into a chosen module in адаптеры/, choose a distinct rule key and set KREST_SNAPSHOT to an ignored local JSON export. The exporter is specific to the owner's system; no private database query, session path or service address is supplied. Every record follows the contract in свой-источник.md.

```python
import datetime as dt
import json
import os
from pathlib import Path

# Replace this with the chosen key in правила.json["источники"].
SOURCE = 'трекер_api'

def собрать(правила, сейчас):
    cfg = правила['источники'].get(SOURCE, {})
    if not cfg.get('enabled', False):
        return {'статус': 'off', 'элементы': [], 'события': []}
    path = os.environ.get('KREST_SNAPSHOT')
    if not path:
        return {'статус': 'off', 'элементы': [], 'события': [], 'заметка': 'No owner snapshot configured'}
    try:
        data = json.loads(Path(path).expanduser().read_text())
        captured = dt.datetime.fromisoformat(data['capturedAt'].replace('Z', '+00:00'))
        expiry = dt.datetime.fromisoformat(data['expiresAt'].replace('Z', '+00:00'))
        if not captured.tzinfo or not expiry.tzinfo or captured > сейчас or expiry <= сейчас:
            raise ValueError('Snapshot expired or invalid')
        rows = data['records']
        for row in rows:
            if row['луч'] not in правила['лучи'] or row['охват'] not in правила['охваты']:
                raise ValueError('Unknown arm or scope')
            row['источник'] = SOURCE
        return {'статус': 'live' if rows else 'quiet', 'элементы': rows,
                'события': [], 'capturedAt': data['capturedAt'],
                'expiresAt': data['expiresAt'], 'заметка': 'Owner-selected snapshot'}
    except Exception:
        return {'статус': 'dead', 'элементы': [], 'события': [], 'заметка': 'Snapshot unavailable or invalid'}
```

| Source | Minimal owner export | Keep private |
| --- | --- | --- |
| Telegram | Counts of explicitly selected unanswered conversations, capture and expiry | Session, API credentials, contact names, text and participant IDs |
| Linear / tracker | Own selected tasks in task JSON | Token, workspace membership, unrelated projects |
| Promises | Explicitly reviewed identity, owner scope, deadline and minimal commitment | Extraction candidates remain separate; transcripts and private database access excluded |
| Infrastructure | Aggregate selected service health, coverage and freshness | Network topology, endpoints, host identities and dependency graph |
| Calls | Explicitly selected existing observation and date | Recording, transcript, attendees and unsolicited inference |

A missing or stale source returns `dead`/`off`, never a healthy zero. Review generated output before sharing; aggregate counts can still reveal private information.
