#!/usr/bin/env bash
# Static checks for the plugin. Needs jq. Runs with no Docker and no network.
set -euo pipefail
cd "$(dirname "$0")/.."
fail=0
bad() { echo "FAIL: $*" >&2; fail=1; }

for f in .claude-plugin/plugin.json .claude-plugin/marketplace.json .mcp.json hooks/hooks.json; do
  jq empty "$f" 2>/dev/null || bad "$f is not valid JSON"
done

# The container must keep every hardening flag.
for flag in "--network none" "--cap-drop ALL" "--security-opt no-new-privileges" \
            "--user vscode" "--pids-limit" "--memory" "readonly" "--rm" "-t stdio"; do
  grep -qF -- "$flag" bin/ghidra-mcp || bad "bin/ghidra-mcp lost '$flag'"
done
grep -qE 'pyghidra-mcp:[0-9.]+@sha256:[0-9a-f]{64}' bin/ghidra-mcp || bad "image is not pinned by digest"

# Scripts run through bash, so they work without the executable bit.
jq -e '.mcpServers.ghidra.command == "bash"' .mcp.json >/dev/null || bad ".mcp.json must run bin/ghidra-mcp through bash"

# The deny hook must block (exit 2).
set +e; bash hooks/deny-mutation.sh 2>/dev/null; rc=$?; set -e
[ "$rc" -eq 2 ] || bad "deny-mutation.sh exited $rc, expected 2"

# Every edit tool in pyghidra-mcp 0.2.7 is in the hook matcher.
for t in rename_function rename_variable set_variable_type set_function_prototype set_comment delete_project_binary; do
  jq -r '.hooks.PreToolUse[0].matcher' hooks/hooks.json | grep -q "$t" || bad "hook matcher misses $t"
done

head -1 skills/binary-triage/SKILL.md | grep -qx -- '---' || bad "SKILL.md has no frontmatter"
grep -q '^name: binary-triage$' skills/binary-triage/SKILL.md || bad "SKILL.md name mismatch"

if command -v shellcheck >/dev/null 2>&1; then
  shellcheck bin/ghidra-mcp hooks/deny-mutation.sh scripts/check.sh || bad "shellcheck"
fi

[ "$fail" -eq 0 ] && echo "OK: all checks passed"
exit "$fail"
