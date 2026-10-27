# Krest

<!-- aim-public-links:start -->
[Лабы AI Mindset](https://aimindset.org/?utm_source=website&utm_medium=article&utm_campaign=start&utm_content=github-toxic-cross#learning) · [База знаний](https://base.aimindset.org/?utm_source=website&utm_medium=article&utm_campaign=start&utm_content=github-toxic-cross)
<!-- aim-public-links:end -->

**See your day. Name its impact.** A local-first Mac menu-bar app and self-hostable workspace for calendar context, personal check-ins and a transparent four-direction model.

[Try the fictional day](https://apps.aimindset.org/krest/demo.html?utm_source=website&utm_medium=article&utm_campaign=start&utm_content=github-toxic-cross) · [Product and download](https://apps.aimindset.org/krest/?utm_source=website&utm_medium=article&utm_campaign=start&utm_content=github-toxic-cross) · [Releases](https://github.com/ai-mindset-org/toxic-cross/releases) · [Method](docs/METHOD.md)

Mac and workspace 3.1 are an **experimental developer preview**. The weights and four-arm construct are inspectable product choices. No health score or psychological diagnosis is inferred. Source calendar events remain read-only.

## Choose your start

| Path | What you get |
| --- | --- |
| Browser demo | A fully fictional day. Try ratings without connecting a source. Entries stay in that browser. |
| Mac app | Native AppKit panel, calendar context, optional feeling/energy ratings, private notes, source freshness and aggregate history. Apple silicon, macOS 13+. |
| Source kit | Native Swift source, web workspace, rule engine, adapters and a loopback API you can run yourself. |

## Set up with your agent

[Configure your rules](https://apps.aimindset.org/krest/build.html#configure), then give Claude Code or Codex this prompt:

```text
Set up Krest on this computer from https://github.com/ai-mindset-org/toxic-cross. Read AGENTS.md and skills/krest/SKILL.md in that repository and follow the local setup protocol. Start with the fictional day, then help me connect one source and apply my attached правила.json. Keep the server on loopback. Ask before installing the Mac app, sending bot messages or enabling any schedule. Show me the working field and a verification receipt.
```

See [package choices](docs/PACKAGE.md), [public boundary](docs/PUBLIC-BOUNDARY.md) and [optional operating templates](docs/OPERATIONS.md).

## Build the Mac app

Requires Apple's Xcode Command Line Tools.

    git clone https://github.com/ai-mindset-org/toxic-cross.git
    cd toxic-cross/native
    make test
    make install

See [native/README.md](native/README.md) for controls, permissions, update/rollback and uninstall. The development build is ad-hoc signed and not notarized; Gatekeeper may block a downloaded copy. The exact release includes SHA-256. There is no automatic updater and no security-bypass installer.

## Run a local workspace

    cd toxic-cross
    python3 собрать.py
    KREST_PORT=8777 python3 server.py

Open http://127.0.0.1:8777/. Default records are fictional. server.py stays on loopback. See [SECURITY.md](SECURITY.md) before any remote deployment. Remote access needs your own authenticated private network and TLS; this experimental API has no independent accounts.

The workspace opens in Overview with the actual calendar day, confirmed plan when available and source-backed context. Cross keeps the original four directions, source colours or monochrome, block hover cards, an inspectable balance dot and a full-field option. Timeline offers Day, Week and Longer with past/upcoming filters and explicit estimated or unknown dates. Changes records incoming source revisions and reversible hide/restore actions. Sources and Method expose freshness, provenance and calculation choices. Keyboard 1–6 switches views. Root, index and workspace entry URLs serve this document directly; the historical instrument remains explicitly under `/classic`.

See [the data-flow ledger](docs/DATA-FLOW.md) for the separate calendar and ratings paths. Connecting a private board enables ratings sync as a separate setting. The Mac app exchanges the same occurrence fingerprints, times, ratings and optional notes with that board. Newer edits win, offline records stay local until acknowledged, and Day/History show a sync receipt. Disable ratings sync in Settings for local-only use. The public demo always uses fictional records and browser-local storage; it cannot connect to a personal board.

## Make it yours

- **Manual context:** copy источники/ручное.json to источники/ручное.local.json and edit the ignored copy.
- **Tasks:** copy источники/задачи.json to источники/задачи.local.json. Keep local records out of Git.
- **ICS:** set KREST_ICS to a file or subscription URL, KREST_MAIL to your own address and optionally KREST_TZ to an IANA time zone. The lightweight legacy ICS adapter has limited recurrence/time-zone handling; native EventKit or Calendar Control is preferred for complex calendars.
- **Calendar Control bridge:** enter your own board URL in native Settings and explicitly enable calendar sharing. It sends selected titles/times, excluding attendees, notes and meeting links. A fresh complete snapshot updates only the calendar lane. No model call or new scheduler is created.
- **Rules:** edit правила.json. Source scales and interpretation are yours to inspect. More adapter detail is in docs/свой-источник.md and адаптеры/ОБРАЗЕЦ.py. New modules require deliberate source changes; imported data never executes code.

Re-run python3 собрать.py after manual source/rule changes. The core is deterministic. An optional existing scheduler can run it in your own deployment; none is installed by the quickstart. Every generated block distinguishes manual annotation from an adapter observation, retains its canonical adapter, and exposes base weight, source multiplier, decay and any manual override. Collection/check time does not replace an upstream capture time. Positions derived from scope defaults are labelled as estimates.

## Mechanism

Obligations, Resources, Past and Future are four views of context. The dot follows declared source weights. Feeling/energy are separate self-reports. A deliberate reframe preview illustrates a different perspective with a visible arbitrary multiplier and leaves original observations intact. Read [the method and evidence limits](docs/METHOD.md).

## Data and trust

Actual day/context files contain titles and may be sensitive. They are private even when message bodies and tokens are excluded. Generated day files, calendars, notes and histories are ignored by Git. Review every public screenshot and use fictional fixtures only. The public website makes no request to a personal board.

Code: [MIT](LICENSE). Bundled fonts: [SIL OFL](ASSET-LICENSES.md). Privacy, storage and network inventory: [SECURITY.md](SECURITY.md). Changes and known limits: [CHANGELOG.md](CHANGELOG.md).

## Preview artwork

The initial HTML includes complete OG/Twitter metadata and a versioned 1200×630 static PNG. `python3 render_preview.py` reproduces the cover from bundled fonts and the authentic Krest/family SVGs using Pillow. Configure deployment-specific canonical and image URLs for a self-hosted installation. The public cover contains no personal records.

Sources can also display an owner-scoped promise registry. Machine-extracted candidates remain separate from scored obligations. Full IDs, exact/window/unknown deadlines, source links and reconciliation flags remain inspectable. Explicit reviewed task identities connect promise, Linear and accepted focus evidence with one representative weight. Existing manual model annotations stay labelled. See [commitment evidence](docs/COMMITMENT-LINKS.md).

## Origin

The “toxic cross” model is Seva Ustinov’s idea, discussed on 15 September 2026. Krest is an attempt to test it hands-on with live data.
