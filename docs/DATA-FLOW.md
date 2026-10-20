# Krest data flow

Implementation checked 2026-10-19. Krest has three separate layers: source context, personal check-ins and a temporary reframe preview. A check-in records your answer about a scheduled occurrence. It does not refresh the source context or move its balance dot.

## Where the context comes from

| Surface | Reads | Produces |
| --- | --- | --- |
| Mac Day | Calendar Control's local `~/.config/calendar-control/google-snapshot.json`; if that file is absent, authorized macOS Calendar via EventKit | Local event list, source freshness, calendar load and opportunities to check in |
| Mac Balance | Configured board's `/контекст.json`; calendar-only mode uses a local calendar calculation | Board model or explicitly labelled local calendar model, plus aggregate local history |
| Private browser workspace | Same board's context JSON and `GET /check-ins` | Day, Research, Sources and Method views |
| Public browser demo | Bundled `site/example-v2.json` | A fictional day; answers stay in that origin's browser storage |

Calendar Control selection filters the snapshot by hidden calendar IDs. An existing unreadable or stale snapshot remains an explicit source problem; it does not silently fall back to EventKit. Spark snapshots expire after 120 seconds; other supported snapshots after one hour. Full-day coverage is required for the local free-time estimate. Calendar Control owns fetching its upstream data. Krest refresh reads the existing local snapshot.

The source kit's [`собрать.py`](../собрать.py) combines manual JSON, calendar bridge or ICS, task JSON and legacy reflections. A separately configured personal deployment can add adapters for accepted daily focus, tasks, commitment records, Telegram counts, vault records, infrastructure and existing call observations. Those adapters run during a context collection. Reading a board or saving a check-in does not run them. A call observation may contain a pre-existing analysis; its presence does not mean that a check-in transcribed or analyzed the call.

Each source receipt reports its status and collection check, plus upstream capture/expiry when supplied. A fresh board response can contain an expired underlying source. The board can also retain dated records. Read each source receipt before treating the picture as current.

## Two independent Mac-to-board exchanges

**Ratings sync:** connecting an eligible private board enables it by default; Settings can turn it off. No board means local-only ratings. Saving on Mac writes `check-ins-v1.json` first, then requests a sync. Panel/source refresh and the minute timer also sync, with a 45-second throttle for ordinary requests. The browser reads on load, visible minute refresh and return to the tab; its save posts directly to the same board.

`POST /check-ins/sync` sends the Mac journal and returns the merged board journal. `POST /check-in` saves one browser entry; `GET /check-ins` reads the journal. Every entry contains exactly:

```text
occurrence, start, end, recorded, feeling, energy, reframe
```

`feeling` and `energy` are both integers from −2 to +2; the form initially shows 0 for each. `reframe` is optional text, up to 280 characters. Titles, attendees, descriptions and meeting URLs are excluded from this record. The optional sentence is still private user-authored text.

Merge uses occurrence identity; the newer `recorded` timestamp wins. Equal timestamps keep the board's existing entry, which the Mac accepts unless it has since made another edit. Failed exchanges retain local data and a pending count. Receipts acknowledge record fingerprints for the selected board. A sync supports at most 5,000 entries; there is no cross-device deletion protocol or full edit history. Removing a calendar event leaves its check-in in the journal.

**Calendar sharing:** this separate setting is off by default. When enabled, a new fresh local capture posts to `/calendar-snapshot`. It includes occurrence fingerprints, titles, scheduled times, all-day status and declined/accepted status, plus capture/coverage metadata. It excludes attendees, notes and meeting URLs. The server saves `источники/calendar-control.json`, replaces the calendar lane in the context, recomputes its arm totals/dot and updates the calendar receipt. Other source adapters are not collected by this request. Ratings sync does not enable calendar sharing.

The native panel reads local events even when its Balance tab uses a broader private board model. Different source selections, rules, freshness or calendar weights can therefore produce different totals. A successful check-in acknowledgement establishes journal sync; it does not establish calendar freshness or equal balances.

## How the same event matches

[`EventReview.key`](../native/swift/EventReview.swift) is SHA-256 of the native calendar occurrence ID. For Calendar Control, that ID combines upstream event ID, start and end; EventKit combines its event identifier and start. The calendar bridge sends that fingerprint unchanged as event `id`. Its board adapter exposes it as `reviewID`. The browser uses `reviewID` first, so a matching Mac and browser event share one journal entry.

Legacy calendar adapters can expose `cal-…` IDs instead. Those entries can sync into history while failing to attach to a native event. Changing calendar backend or occurrence times can also change the fingerprint. Matching is exact; no title-based reconciliation is attempted.

## What an interaction changes

| Action | Persistent effect |
| --- | --- |
| Save check-in | Journal entry and, when enabled, its private-board copy; visible ratings/history |
| Skip/close | No journal write |
| Research reframe preview | No persistent write; selected weights are illustrated with the visible multiplier |
| Source refresh | Re-read existing board/local data; optional fresh calendar sharing may update the calendar lane |
| Full collection | Rebuild context from configured adapters and rules, retaining hidden source records |
| Hide / restore block | Save board visibility and recompute active arm totals/dot; upstream source unchanged |
| Legacy `/правка` or `/отклик` | Separate manual changes/reflection files consumed by a later collection |

The reframe preview keeps the observed normalization constant. Its default ×0.25 multiplier makes the selected weights lighter and recomputes an illustrative dot. It does not save your interpretation or modify the source records. The optional check-in sentence is saved separately and does not feed the weight formula. See [method and evidence limits](METHOD.md).

## Storage and navigation

Mac private files live under `~/Library/Application Support/Krest/`: `check-ins-v1.json`, board-scoped `check-in-sync-v1.<fingerprint>.json` receipts and `history-v1.json` aggregates. The check-in journal is shared across configured destinations: choosing another private board shares the existing local journal with that board. Receipts and aggregate history are scoped by source; event check-ins are not separated into per-board journals.

The board keeps `источники/check-ins.local.json` separately from generated context/history. Public demo entries use `localStorage` key `krest.demo.checkins.v2` and never call journal endpoints. The native ratings client rejects known public demonstration hosts. The public website has no personal-board connection setting. [SECURITY.md](../SECURITY.md) contains the network/privacy boundary.

Native **Open private board** opens the configured root; **Open research board** adds `#research`. The current workspace is served directly at the root. `/classic` explicitly opens the historical instrument; its old controls and animations have separate behavior. Use the current workspace for the method described here.

## Source changes and reversible visibility (3.0)

`board_state.py` retains the complete source snapshot separately from the visible projection in ignored `источники/board-state.local.json` (mode 0600, atomic writes and a shared directory lock). Each record receives a stable `boardKey` from its source identity. `GET /board-state` returns hidden-record receipts and the bounded change journal; the raw state file is not exposed as a static download. `POST /board/visibility` accepts `{key, hidden}` and returns the updated projected context and state. Unknown or ambiguous identities are not merged.

Hide removes that record from the active four-arm calculation and moves the source-balance dot. Restore recomputes it from the retained current source. Calendar replacement and full collection both use the full snapshot, so refresh does not accidentally restore hidden blocks. A record removed upstream is marked absent; restoring visibility does not resurrect it. Check-ins and upstream tasks/calendar events are untouched. The browser offers Undo and a hidden-record list.

Changes distinguish added/changed/removed source records from hide/restore actions and rule recalculation, with weight deltas when available. The log starts when this state store is first used; it is not a reconstructed lifetime history. Repeated identical source captures do not add duplicate entries. A maximum of 600 changes is retained.

The public demo uses `krest.demo.board.v3` browser storage for visibility and changes, and never sends these operations to a private API. Only source-backed entries confirmed by the user (`confirmed_by_user: true`) appear as the accepted plan. Missing/expired focus inputs remain explicit. Unaccepted obligations are suggestions.

Mac 3.0 opens Overview, original Cross, day Timeline and Changes through the configured private address. Its existing one-minute source polling reads the same projected totals; ratings continue through the separate occurrence journal. Reminder preferences remain controlled in Mac Settings; the browser does not request notification permission.
