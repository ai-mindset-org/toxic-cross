# Optional operating templates

Nothing in this folder installs itself. First verify a fictional loopback field with AGENTS.md. Choose one scheduler per job and check the owner's existing schedules. Before installation show the exact resolved paths, time zone, cadence, writes and removal command; obtain consent. Replace every placeholder with the owner's values. Keep a private environment file mode 0600, based on `.env.example`.

## Mac · launchd collection template

Save the reviewed template as the owner's `~/Library/LaunchAgents/org.krest.collect.plist`. launchd requires absolute paths: replace PYTHON, CHECKOUT and PRIVATE_LOG with actual values. No shell expansion occurs inside ProgramArguments. Add explicitly chosen environment variables through EnvironmentVariables. Keep the ICS URL and tokens out of shared logs.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>Label</key><string>org.krest.collect</string>
<key>ProgramArguments</key><array><string>PYTHON</string><string>CHECKOUT/собрать.py</string></array>
<key>WorkingDirectory</key><string>CHECKOUT</string>
<key>StartInterval</key><integer>600</integer>
<key>StandardOutPath</key><string>PRIVATE_LOG</string>
<key>StandardErrorPath</key><string>PRIVATE_LOG</string>
</dict></plist>
```

After consent: `launchctl bootstrap gui/$(id -u) "$HOME/Library/LaunchAgents/org.krest.collect.plist"`. Inspect with `launchctl print gui/$(id -u)/org.krest.collect`. Remove with `launchctl bootout gui/$(id -u)/org.krest.collect`, then remove only this plist after review. Collection is one-shot; an optional separate server job uses server.py and KREST_PORT on loopback with KeepAlive. Do not enable autostart implicitly.

## Linux · systemd user templates

Place these only after review under the owner's `~/.config/systemd/user/`. Replace `%h/krest` with the chosen checkout if different and set the actual Python executable. Service names and environment variable names stay ASCII.

```ini
# krest-collect.service
[Unit]
Description=Krest context collection
[Service]
Type=oneshot
WorkingDirectory=%h/krest
EnvironmentFile=%h/.config/krest/env
ExecStart=/usr/bin/python3 %h/krest/собрать.py

# krest-collect.timer (a separate file)
[Unit]
Description=Krest collection cadence
[Timer]
OnBootSec=2min
OnUnitActiveSec=10min
[Install]
WantedBy=timers.target
```

After consent: `systemctl --user daemon-reload` and `systemctl --user enable --now krest-collect.timer`. Verify `systemctl --user list-timers krest-collect.timer` and the service journal. Remove with `systemctl --user disable --now krest-collect.timer`, then review removal of those exact two files. `loginctl enable-linger` is a separate owner/admin choice if the schedule must survive logout.

For a server service, use `Type=simple`, `ExecStart=/usr/bin/python3 %h/krest/server.py`, `Environment=KREST_PORT=8777` and `Restart=on-failure`; keep the bind on loopback. Private remote access requires a separately reviewed authenticated/TLS route. No public proxy or network repair is installed by this kit.

## Ritual and watchdog jobs

Run `python3 docs/ritual.py` to inspect a dry-run URL-button payload. Set your own KREST_PRIVATE_URL and KREST_CHAT_ID. Keep KREST_BOT_TOKEN out of command arguments and logs. Use `--send` only after explicit delivery authorization. No getUpdates consumer is created; URL buttons open the private /отклик form and the person explicitly submits an answer.

An optional ritual job uses this same one-shot service pattern with `ExecStart=... docs/ritual.py --send`, an owner-approved environment and explicit daily times. For example, `OnCalendar=*-*-* 09:30:00 Etc/UTC` with `Persistent=false` avoids replaying missed prompts. Review cadence, time zone, quiet hours and daily limit before enabling. On Mac use StartCalendarInterval with Hour/Minute in the Mac's current time zone. Do not enable both scheduler lanes.

`python3 docs/healthcheck.py` reports `local 200`, plus `private remote 200` when KREST_PRIVATE_URL is set. Reuse the one-shot template at a chosen five-minute interval if wanted. It neither changes routes nor restarts anything. An optional recovery action must name only the exact owner-approved Krest server service and have a bounded restart policy; systemd Restart handles process exits. Never disable TLS verification or widen the listening interface to pass a health check.

## Product film

The short landing uses a genuine poster and explicit play button immediately after the live cross. The reviewed film is `site/assets/krest-demo.mp4`, with `krest-demo-poster.jpg`; its source is the separate product-demo workflow. Playback starts only on the person's click and starts muted. Agent checks keep it muted. Preserve those assets when updating the page, and mirror reviewed changes into the existing hosting folder. No native app rebuild is involved.
