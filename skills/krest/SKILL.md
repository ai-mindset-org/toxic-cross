---
name: krest
description: Use when setting up Krest on a computer, connecting a first personal source, applying configurator rules, or preparing an optional private ritual and schedule.
---

# Your own Krest

Read the repository's `AGENTS.md` for the executable setup protocol. Use the following six checkpoints; continue within the person's requested scope.

1. **Fictional field.** Check Python 3.10+, Git and an available loopback port. Use a clean clone or isolated checkout. Run `python3 собрать.py` and `KREST_PORT=8777 python3 server.py`. Verify HTTP 200 and a rendered field before adding personal sources.
2. **First source.** Prefer a local ICS export or ignored manual JSON, then task JSON. The public fixtures must remain fictional. Show the source receipt, coverage and freshness. Read `docs/свой-источник.md` before adding an adapter. API tracker, Telegram, promises, infrastructure and call integrations require the person's own accounts and explicit data selection; see `docs/ADAPTER-TEMPLATES.md`.
3. **Rules.** Use the person's downloaded `правила.json` from the configurator, backing up existing rules. Rebuild and show how a source weight changes the balance. Scope defaults are 1/7/45-day half-lives. Weights are declared choices, with no psychological calibration.
4. **Optional ritual.** Offer `docs/ritual.py` and `docs/.env.example`. Use the person's own bot and chat. Produce a dry-run payload first. Send only with explicit delivery authorization. Use URL buttons to the private response page; do not add a second `getUpdates` reader to a token with an existing owner. Opening a URL never saves an answer; the person submits the form.
5. **Optional schedule and watchdog.** Offer the launchd or systemd templates in `docs/OPERATIONS.md`. Check existing schedulers first. Explain exact files, cadence and removal. Install or enable only with consent. A health check reports status; recovery is limited to the exact owner-approved service. Never widen the loopback binding or repair a network route automatically.
6. **Before showing.** Inspect generated JSON, ignored sources, rules and screenshots for private titles, identities, endpoints and secrets. Run the checks in `AGENTS.md`. Give the local URL, source receipt, changed files, active schedules and stop/removal commands. A real day is private even if it excludes message bodies.

The Mac app is optional. An unsigned developer preview may be blocked by Gatekeeper; never disable platform protections. Read `native/README.md` and `SECURITY.md`. Remote use needs the person's authenticated private access and TLS, separately from the local setup.
