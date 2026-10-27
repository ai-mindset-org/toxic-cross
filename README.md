<picture>
  <img src="site/assets/readme-banner.svg" alt="AI Mindset · Krest · your day, in four directions" width="1200">
</picture>

**See obligations, resources, past and future in one field.** Try a fictional day, choose your weights and build a private cross on your own data.

[**try the demo**](https://apps.aimindset.org/krest/demo.html?utm_source=github&utm_medium=readme&utm_campaign=krest#research) · [**download for Mac**](https://apps.aimindset.org/krest/?utm_source=github&utm_medium=readme&utm_campaign=krest#mac) · [**configure**](https://apps.aimindset.org/krest/build.html?utm_source=github&utm_medium=readme&utm_campaign=krest#configure) · [**set up with your agent**](https://apps.aimindset.org/krest/?utm_source=github&utm_medium=readme&utm_campaign=krest#install)

![The Krest cross: declared weights, a balance dot and a reversible perspective preview on fictional data](site/assets/krest-in-motion.gif)

## Make it yours in 5 steps

1. **Copy the prompt to Claude Code or Codex.** Your agent gets the setup guide.
2. **Start a fictional day.** Your agent opens a working cross on your computer.
3. **Choose the weights.** [Configure](https://apps.aimindset.org/krest/build.html?utm_source=github&utm_medium=readme&utm_campaign=krest#configure), watch the dot move and download `правила.json`.
4. **Connect one source.** Your own calendar or manual notes appear with a source receipt.
5. **Add the Mac app, if you like.** Keep a compact view in your menu bar.

The guide comes from [AGENTS.md](AGENTS.md) in this repository. The [agent skill](skills/krest/SKILL.md) follows the same five steps.

<details>
<summary>Copy the setup prompt</summary>

```text
Set up Krest on this computer from https://github.com/ai-mindset-org/toxic-cross. Read AGENTS.md and skills/krest/SKILL.md. Follow the five steps: copy this brief, start the fictional day on loopback, help me choose and apply правила.json at https://apps.aimindset.org/krest/build.html#configure, connect one source I choose, and optionally add the Mac app. Ask before installing an app, sending a bot message or enabling a schedule. Show me the working cross and a short verification receipt.
```

</details>

<details>
<summary>Run the fictional day yourself</summary>

```sh
git clone https://github.com/ai-mindset-org/toxic-cross.git
cd toxic-cross
python3 собрать.py
KREST_PORT=8777 python3 server.py
```

Open http://127.0.0.1:8777/ and choose Cross. Python 3.10+; no account. The server stays on loopback. Preserve personal sources in ignored local files. [Source contract](docs/свой-источник.md) · [operating templates](docs/OPERATIONS.md).

</details>

## How to read it

**Up:** obligations. **Down:** resources. **Left:** past experience. **Right:** possible futures.

A block's distance shows time, its size shows declared weight. The red dot shows the balance of those weights. Flip offers a temporary perspective preview; source records remain intact. Weights and the four-arm construct are experimental choices, with no psychological calibration. A calendar event ending does not establish completion or how it felt.

The Mac companion adds optional feeling/energy check-ins and aggregate history. Check-ins form a separate journal and do not change source weights. Calendar sharing and ratings sync are separate controls. [Method](docs/METHOD.md) · [data flow](docs/DATA-FLOW.md).

## Your data and your copy

The demo is fictional. Your own board, calendar titles, tasks, notes and histories stay private. Read-only source adapters and explicit rules make the calculation inspectable. Keep the server on loopback; remote use requires your own authenticated private access and TLS. [Security](SECURITY.md) · [public boundary](docs/PUBLIC-BOUNDARY.md).

Mac 3.1.0 build 13 is an Apple silicon/macOS 13+ developer preview, ad-hoc signed and not notarized. Gatekeeper may block a download. Updates are manual. [Release and SHA-256](https://github.com/ai-mindset-org/toxic-cross/releases/tag/v3.1.0) · [native source and installation](native/README.md).

Code: [MIT](LICENSE). Fonts: [SIL OFL](ASSET-LICENSES.md). [Changelog](CHANGELOG.md) · [package and landing pattern](docs/PACKAGE.md) · [reusable README template](docs/README-TEMPLATE.md).

## Origin

The “toxic cross” model is Seva Ustinov’s idea, discussed on 15 September 2026. Krest is an attempt to test it hands-on with live data.

Made inside [AI Mindset labs](https://aimindset.org/?utm_source=github&utm_medium=readme&utm_campaign=krest#learning).
