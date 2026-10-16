# Contributing

Keep changes small and explain the user-visible behavior. Use fictional fixtures. Never commit private context, calendar exports, tokens, transcripts, personal endpoints or histories.

- Mac: make -C native test. The native panel is AppKit; shared shell files retain provenance digests.
- Browser: node --check движок/workspace-v2.js and node workspace.test.cjs.
- Server: python3 -m unittest test_server.py. Run a local instance on loopback for manual integration.
- Weights and method: document the rule version, source, unknown states and any change in interpretation. Custom weights are planning choices, not clinical measurements.

Adapters are read-only input modules. Keep secrets in environment variables and user data in ignored local files. No imported JSON may execute code. Build releases from reviewed commits and attach exact checksums and honest signing status.
