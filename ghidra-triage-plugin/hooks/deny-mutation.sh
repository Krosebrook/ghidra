#!/usr/bin/env bash
# Triage is read-only. Exit code 2 blocks the tool call and shows stderr to Claude.
echo "ghidra-triage: Ghidra edit tools are blocked during triage. Record names and notes in the report instead." >&2
exit 2
