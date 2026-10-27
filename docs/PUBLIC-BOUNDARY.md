# Public boundary

Audit date: 27 October 2026. The private implementation was read for mechanisms only. The running private deployment was checked read-only: ritual, watchdog, timer and five adapter files match the audited local source by SHA-256. No private snapshots, identities, source paths, chat IDs, tokens or endpoint defaults are included here. Real calendar/task titles and aggregate day files can disclose private information.

| Function | Public decision | Shipped form / boundary |
| --- | --- | --- |
| Four directions, weighted records, timeline and source receipts | Public | Existing source engine and fictional browser fixture |
| Weights, source selection, scopes, 1/7/45-day half-lives and signal threshold | Public | Browser configurator and compatible правила.json |
| Bot ritual with URL buttons | Template | docs/ritual.py, own bot token/chat and private authenticated board URL; dry-run default; explicit --send only after authorization; no updates polling |
| Response submission | Public | Existing /отклик page and POST, own journal; opening the URL does not save an answer |
| Static/API health watchdog | Template | docs/healthcheck.py checks loopback and optionally the owner's HTTPS endpoint; reports failure; scoped recovery belongs to the owner's explicit service policy |
| Collection schedule | Template | systemd and launchd examples in OPERATIONS.md; no automatic installation |
| Ritual timers and quiet hours | Template | Owner-selected time zone and cadence; no personal schedule copied; one scheduler per outcome |
| Partial reframe with recoil | Public, historical | Existing /classic engine; optional illustrative animation only, documented in METHOD.md; no automatic ritual or therapeutic claim |
| Telegram read adapter | Template | Own read-only normalized snapshot contract in ADAPTER-TEMPLATES.md; session, API credentials, contact identities and correspondence remain private |
| Linear task adapter | Template | Own export to the existing tasks JSON adapter; optional read-only API route described in ADAPTER-TEMPLATES.md; no personal token or workspace IDs |
| Promise registry | Template | Own reviewed/consented registry and explicit source identity; candidates stay separate from counted obligations. Private queries, owner IDs, hosts and snapshots excluded |
| Infrastructure observations | Template | Own normalized status snapshot with capture/expiry; no private topology, host IDs or relationship graph |
| Call observations | Template | Only explicitly selected existing observations and minimal facts in the owner's normalized snapshot; no private transcripts or call content copied |
| Manual context and feelings | Private data | Blank/fictional fixtures only; real annotations and separate check-in journal stay local |
| Source exports, histories, environment files, bot state and private overrides | Excluded | Ignored private storage, never static hosting or a release asset |
| Personal source adapters with hard-coded accounts, database queries and infrastructure | Excluded | Replaced by owner-configurable templates; private implementation is not copied |

Read SECURITY.md before connecting a source or enabling remote access. “No message bodies” is not a public-data guarantee. The configurator only handles rules; it never connects to these accounts. See OPERATIONS.md for optional deployment templates and exact consent boundaries.
