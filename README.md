# Krest

**See your day. Name its impact.** A local-first Mac menu-bar app and self-hostable workspace for calendar context, personal check-ins and a transparent four-direction model.

[Try the fictional day](https://apps.aimindset.org/krest/demo.html) · [Product and download](https://apps.aimindset.org/krest/) · [Releases](https://github.com/ai-mindset-org/toxic-cross/releases) · [Method](docs/METHOD.md)

Version 2.0 is an **experimental developer preview**. The weights and four-arm construct are inspectable product choices. No health score or psychological diagnosis is inferred. Source calendar events remain read-only.

## Choose your start

| Path | What you get |
| --- | --- |
| Browser demo | A fully fictional day. Try ratings without connecting a source. Entries stay in that browser. |
| Mac app | Native AppKit panel, calendar context, optional feeling/energy ratings, private notes, source freshness and aggregate history. Apple silicon, macOS 13+. |
| Source kit | Native Swift source, web workspace, rule engine, adapters and a loopback API you can run yourself. |

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

The workspace shows Today, Balance, Sources and Method. Each event can receive your feeling and energy rating and an optional sentence. Upcoming/current/earlier phases follow the clock; an ended event does not establish completion. Browser-board and native check-in stores are separate in v2.

## Make it yours

- **Manual context:** copy источники/ручное.json to источники/ручное.local.json and edit the ignored copy.
- **Tasks:** copy источники/задачи.json to источники/задачи.local.json. Keep local records out of Git.
- **ICS:** set KREST_ICS to a file or subscription URL, KREST_MAIL to your own address and optionally KREST_TZ to an IANA time zone. The lightweight legacy ICS adapter has limited recurrence/time-zone handling; native EventKit or Calendar Control is preferred for complex calendars.
- **Calendar Control bridge:** enter your own board URL in native Settings and explicitly enable calendar sharing. It sends selected titles/times, excluding attendees, notes and meeting links. A fresh complete snapshot updates only the calendar lane. No model call or new scheduler is created.
- **Rules:** edit правила.json. Source scales and interpretation are yours to inspect. More adapter detail is in docs/свой-источник.md and адаптеры/ОБРАЗЕЦ.py. New modules require deliberate source changes; imported data never executes code.

Re-run python3 собрать.py after manual source/rule changes. The core is deterministic. An optional existing scheduler can run it in your own deployment; none is installed by the quickstart.

## Mechanism

Obligations, Resources, Past and Future are four views of context. The dot follows declared source weights. Feeling/energy are separate self-reports. A deliberate reframe preview illustrates a different perspective with a visible arbitrary multiplier and leaves original observations intact. Read [the method and evidence limits](docs/METHOD.md).

## Data and trust

Actual day/context files contain titles and may be sensitive. They are private even when message bodies and tokens are excluded. Generated day files, calendars, notes and histories are ignored by Git. Review every public screenshot and use fictional fixtures only. The public website makes no request to a personal board.

Code: [MIT](LICENSE). Bundled fonts: [SIL OFL](ASSET-LICENSES.md). Privacy, storage and network inventory: [SECURITY.md](SECURITY.md). Changes and known limits: [CHANGELOG.md](CHANGELOG.md).
