# Krest for Mac – 2.0.0

Native AppKit menu-bar app. Apple silicon, macOS 13+; Xcode Command Line Tools required to build.

    make test
    make install
    make dist

The installation is scoped to ~/Applications/krest.app and one org.aimindset.krest.bar LaunchAgent. It backs up the old app, preferences, aggregate history and check-ins before replacing the bundle. Source builds are ad-hoc signed. Public development downloads may be blocked by Gatekeeper; Developer ID notarization is still outstanding.

## Use

Click the menu-bar mark or press Option-Command-X. Tabs: Balance, Day, History, Settings. Command-K opens actions; Command-comma opens Settings; Escape returns from a check-in/Settings and then closes the panel. The header's circle pins the panel open. The balance dot is a separate source indicator.

In Day, choose an event and Check in. Feeling and energy are optional −2…+2 personal reports, with an optional private sentence. Check-ins stay in a separate local file. Calendar, private-board balance and personal ratings remain separately labelled.

Settings chooses the board URL, optional calendar sharing, check-in reminders, menu appearance, panel pin, theme and hotkey. Calendar sharing is off by default and explicitly sends titles/times to the configured private board. A calendar-only workflow is supported. EventKit access is requested only when needed; calendar events are never edited.

Check-in reminders are off by default. Enabling asks macOS notification permission. One quiet generic prompt per day, 08:00–21:00, after a freshly observed event ends. No event title is displayed and no missed prompts are replayed after wake.

## Storage and removal

Private files under ~/Library/Application Support/Krest/: history-v1.json (aggregates), check-ins-v1.json (fingerprints, times, ratings and your optional sentence), Backups/ (scoped install rollback). Preferences use org.aimindset.krest.bar. These stores are not encrypted by the application. Native check-ins and browser-board check-ins are separate in v2.

Run make uninstall to remove the app and its LaunchAgent. Data is retained intentionally. Export or back up the files before choosing to delete them yourself.

## Diagnostics

    build/Krest.app/Contents/MacOS/Krest --check-calendar
    build/Krest.app/Contents/MacOS/Krest --check-source
    build/Krest.app/Contents/MacOS/Krest --history-summary
    build/Krest.app/Contents/MacOS/Krest --render-fixture /tmp/krest-fictional.png --day

Fixture rendering is offscreen and reads no personal sources. Source checks print content-free counts and freshness.

Code: ../LICENSE. Font notice: assets/aim-plex-LICENSE.txt. Data boundary: ../SECURITY.md. Method: ../docs/METHOD.md.
