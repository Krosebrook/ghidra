# ghidra-triage

A Claude Code plugin that triages a suspicious binary into a structured report. It uses Ghidra through [pyghidra-mcp](https://github.com/clearbluejar/pyghidra-mcp) (Apache-2.0), which runs in a Docker container with no network.

Scope for the first 90 days: one user, one workflow (triage one binary into one report).

## What is in the plugin

| Path | Purpose |
|---|---|
| `.claude-plugin/plugin.json` | Plugin manifest |
| `.mcp.json` | Registers the `ghidra` MCP server (runs `bin/ghidra-mcp`) |
| `bin/ghidra-mcp` | Starts pyghidra-mcp over stdio in a hardened container |
| `skills/binary-triage/` | The triage workflow, safety rules and report template |
| `commands/triage.md` | `/triage <file>` slash command |
| `hooks/` | Blocks the Ghidra edit tools, so triage stays read-only |
| `scripts/check.sh` | Static checks (JSON, hardening flags, hook behaviour) |

## Set up

1. Install Docker and start it.
2. Pull the pinned image once (the container has no network, so it cannot pull at start):
   ```bash
   docker pull ghcr.io/clearbluejar/pyghidra-mcp:0.2.7@sha256:f433dd622b4b1c9637476a6ad4bde310ae63b661838c50eaf7d62a8402e73fa9
   ```
3. Create the sample folder and put the sample in it:
   ```bash
   mkdir -p ~/ghidra-samples
   cp /path/to/suspicious.bin ~/ghidra-samples/
   ```
4. Load the plugin:
   ```bash
   claude --plugin-dir /path/to/ghidra-triage-plugin
   ```
   Or add it as a local marketplace: `/plugin marketplace add /path/to/ghidra-triage-plugin`, then `/plugin install ghidra-triage@ghidra-triage-marketplace`.
5. Run `/triage suspicious.bin`. The report goes to `triage-reports/` in the current folder.

Settings (environment variables):

| Variable | Default | Meaning |
|---|---|---|
| `GHIDRA_TRIAGE_SAMPLES` | `~/ghidra-samples` | Host folder mounted read-only at `/samples` |
| `GHIDRA_TRIAGE_IMAGE` | pinned 0.2.7 digest | Override the image |
| `GHIDRA_TRIAGE_MEMORY` | `4g` | Container memory limit |

## Threat model

The sample is hostile. The plugin assumes it can contain anything, including text written to manipulate the model that reads it.

| Threat | Control |
|---|---|
| Sample code runs on the host | Claude never executes the sample (skill rule). Ghidra only parses it, inside a container. |
| Parser exploit in Ghidra or a loader | Container: `--network none`, `--cap-drop ALL`, `--security-opt no-new-privileges`, non-root user, memory and pids limits, `--rm`. |
| Sample tampered with or host files changed | Sample folder is mounted read-only. Nothing else from the host is mounted. The Ghidra project lives in the container and is discarded on exit. |
| Data leaves the machine from inside the container | No network in the container. |
| Prompt injection in strings, symbols or decompiled code | Skill treats all tool output as data, quotes suspicious text under "Prompt-injection attempts", never fetches indicators, defangs them. |
| Model is tricked into changing the Ghidra project | PreToolUse hook blocks every pyghidra-mcp edit tool. |
| Supply chain change in the image | Image pinned by digest, not by tag. |

What this does **not** protect against:

- A container escape through a kernel or Docker bug. For live malware, run this on a disposable VM, not your daily machine.
- Prompt injection that changes the report's conclusions without looking like an instruction. Treat the verdict as a lead for a human analyst, not a final call.
- Other tools in your Claude Code session. If the session also has shell, web or email tools, injected text could try to reach them. Run triage in a session with only this plugin when possible.

## Checks

```bash
bash scripts/check.sh
```

This validates the JSON files, confirms every hardening flag is still in `bin/ghidra-mcp`, confirms the image is pinned by digest, and confirms the hook blocks with exit code 2. It needs `jq`. It does not start the container.

## Move to its own repository

This folder is self-contained. To split it out with its history:

```bash
git subtree split --prefix=ghidra-triage-plugin -b ghidra-triage-only
git push git@github.com:Krosebrook/ghidra-triage.git ghidra-triage-only:main
```

Create the empty `Krosebrook/ghidra-triage` repository on GitHub first. After the split, `/plugin marketplace add Krosebrook/ghidra-triage` works because `.claude-plugin/marketplace.json` is at the new repository root.

## Known gaps

- The container start was not tested end to end yet. Run `/mcp` in Claude Code after setup and confirm the `ghidra` server is connected.
- Semantic `search_code` may need an embedding model download, which the no-network container cannot do. The skill uses `search_mode="literal"`.
- The `--user vscode` setting relies on the user in the upstream image. If the image changes, check it with `docker run --rm --entrypoint id <image>`.
