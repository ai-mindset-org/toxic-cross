# Privacy and security

Krest 2.0 is an experimental single-user tool. Report security issues privately through the repository owner's GitHub contact before publishing sensitive details.

## What stays where

- The Mac app reads a selected local Calendar Control snapshot, or macOS Calendar through EventKit. It does not edit events.
- Aggregate history stores capture times, x/y, arm totals/counts and source states. It excludes event titles, task text and messages. It lives at ~/Library/Application Support/Krest/history-v1.json.
- The separate check-ins-v1.json stores an occurrence fingerprint, start/end times, answer time, feeling, energy and your optional sentence. It excludes event titles, attendees, descriptions and meeting URLs. Files are written atomically with mode 0600. This is filesystem privacy, not application-level encryption.
- Calendar and notification permissions are separate. Check-in reminders are off by default, at most once daily during 08:00–21:00, with a generic body and no event title. Sleep or Focus may prevent delivery. No backlog is replayed after wake.
- Connecting a private board makes HTTP requests to that address. Optional calendar sharing sends selected event titles and times to that board, excluding attendees, notes and meeting URLs. Source freshness stays visible. Public demo interactions never call a private board.
- Browser check-ins on your own board are saved on that board. Public fictional demo check-ins stay in browser localStorage. These stores are separate from native local check-ins in v2.
- Exported JSON may contain your notes. Backups, exports, server administrators and other privileged software are outside this tool's protection. Removing a calendar event does not remove a separate check-in automatically.

## Self-hosting boundary

server.py binds to 127.0.0.1 by default. Keep it there for local use. The API has no independent account authentication. Do not expose the process to a public host, port forward or general LAN. Remote use requires your own authenticated private network and TLS. A trusted network is a deployment assumption, not an app-level user identity.

JSON writes are bounded, schema-checked and Origin-checked. POST Host values accept loopback and private Tailscale names by default; explicit trusted names can be supplied through KREST_ALLOWED_HOSTS. No permissive CORS is added. This is not a security audit. Arbitrary adapters or modified source inherit the running user's access.

## Public material

Publish fictional fixtures only. Actual day.json / контекст.json, histories, calendar snapshots, check-in records, transcripts, private endpoints and environment secrets are private. Short event/task titles can disclose sensitive facts. A lack of message bodies does not make a day file safe to publish.

## Distribution

The current development build is ad-hoc signed and is not notarized. A checksum identifies exact bytes; it does not prove safety. Developer ID notarization remains an explicit release requirement for a smooth public installation. No instructions here disable Gatekeeper or strip quarantine.
