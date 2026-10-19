# Krest for Mac – 2.1.0

Native AppKit menu-bar app. Apple silicon, macOS 13+; Xcode Command Line Tools required to build.

    make test
    make install
    make dist

The installation is scoped to ~/Applications/krest.app and one org.aimindset.krest.bar LaunchAgent. It backs up the old app, preferences, aggregate history and check-ins before replacing the bundle. Source builds are ad-hoc signed. Public development downloads may be blocked by Gatekeeper; Developer ID notarization is still outstanding.

## Use

Click the menu-bar mark or press Option-Command-X. Tabs: Balance, Day, History, Settings. Command-K opens actions; Command-comma opens Settings; Escape returns from a check-in/Settings and then closes the panel. The header's circle pins the panel open. The balance dot is a separate source indicator.

In Day, choose an event and Check in. The check-in is voluntary. Saving records both feeling and energy on the −2…+2 scale, initially 0 for each, plus an optional private sentence. Review both values before saving; close or skip to leave the event unrecorded. Check-ins stay in a separate local file. Calendar, private-board balance and personal ratings remain separately labelled. See [the data-flow ledger](../docs/DATA-FLOW.md) for what each action changes and how events match.

An existing private-board connection enables **ratings sync** by default. Settings can turn it off; with no board it stays off. Save writes locally first, then exchanges check-ins with that board. Opening the panel and the minute source check also exchange records. Day and History show the source, last successful check and pending count. An unavailable board leaves local entries intact, ready for the next exchange. Replies merge by occurrence, with the newest recorded time winning; a reply in flight cannot overwrite a newer edit. Browser check-ins become visible in History and on matching calendar events in Day.

**Open research board** is available in Balance, Day and the actions menu. It opens the configured board at `#research`; the 520×690 native panel retains its four tabs.

Settings chooses the board URL, ratings sync, optional calendar sharing, check-in reminders, menu appearance, panel pin, theme and hotkey. Ratings sync shares occurrence fingerprints, start/end/recorded timestamps, feeling, energy and the optional sentence. Event titles and URLs are excluded. Known public demonstration hosts are rejected for ratings sync and HTTP redirects are refused. Calendar sharing is a separate setting, off by default, and explicitly sends titles/times to the configured private board. A calendar-only workflow is supported. EventKit access is requested only when needed; calendar events are never edited.

Check-in reminders are off by default. Enabling asks macOS notification permission. One quiet generic prompt per day, 08:00–21:00, after a freshly observed event ends. No event title is displayed and no missed prompts are replayed after wake.

## Storage and removal

Private files under ~/Library/Application Support/Krest/: history-v1.json (aggregates), check-ins-v1.json (fingerprints, times, ratings and your optional sentence), check-in-sync-v1.<board fingerprint>.json (content-free acknowledged fingerprints and check time), Backups/ (scoped install rollback). Preferences use org.aimindset.krest.bar. These stores are not encrypted by the application. v2.1 imports existing native records without changing their date encoding; sync uses ISO8601 UTC dates on the wire. A connection shares the existing local journal; switching to another private board shares that journal with the newly chosen destination.

Private calendar bridge IDs already match across surfaces: `EventReview.key` is SHA256 of the native calendar occurrence ID and is sent unchanged as the calendar snapshot event `id`; the board exposes it as `reviewID`. Legacy board `cal-…` IDs remain in History but cannot automatically match a native event. No title-based matching is attempted.

## Sync contract and checks

`POST <board-root>/check-ins/sync` sends `{entries:[{occurrence,start,end,recorded,feeling,energy,reframe}]}` and receives `{ok:true,entries:[…]}` (optional outer revision). One exchange is bounded to 5,000 entries, an 8 MB reply and an 8-second timeout. Unknown entry fields, duplicates, invalid ratings, future recorded times beyond five minutes and malformed replies are rejected without changing local records. The existing board `GET /check-ins` remains compatible. Check-in sync never requests a calendar/source refresh or changes reminder settings.

`make test` includes an offscreen control walk, theme regression and deterministic sync transport tests: offline persistence, browser import, newest edits during an in-flight request, durable acknowledgements, malformed data, opt-out during a request, public demo exclusion and research navigation. No install, foreground window, private calendar read or notification permission is needed for those test lanes (the optional source diagnostic uses the configured board).

`bash tests/check-in-http.sh` additionally starts the production Python API on an ephemeral loopback port with a temporary journal and exercises native `URLSession` directly: browser POST → native import, native save → server journal, newest browser conflict, union and repeat sync with zero pending. Python's UTC `+00:00` timestamps are checked across the real exchange. The harness stops its own server and removes all fixture files; it never uses `KrestURL` or a personal board.

Run make uninstall to remove the app and its LaunchAgent. Data is retained intentionally. Export or back up the files before choosing to delete them yourself.

## Diagnostics

    build/Krest.app/Contents/MacOS/Krest --check-calendar
    build/Krest.app/Contents/MacOS/Krest --check-source
    build/Krest.app/Contents/MacOS/Krest --history-summary
    build/Krest.app/Contents/MacOS/Krest --render-fixture /tmp/krest-fictional.png --day

Fixture rendering is offscreen and reads no personal sources. Source checks print content-free counts and freshness.

Code: ../LICENSE. Font notice: assets/aim-plex-LICENSE.txt. Data boundary: ../SECURITY.md. Method: ../docs/METHOD.md.
