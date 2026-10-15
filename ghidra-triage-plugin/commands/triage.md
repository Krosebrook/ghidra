---
description: Triage a suspicious binary into a structured report
argument-hint: <file name in the sample folder>
---

Triage the binary `$ARGUMENTS` with the `binary-triage` skill.

The file must already be in the sample folder on the host (default `~/ghidra-samples`, or `$GHIDRA_TRIAGE_SAMPLES`). Inside the container that folder is `/samples`, so import `/samples/$ARGUMENTS`.

If `$ARGUMENTS` is empty, ask which file in the sample folder to triage. Do not import the whole folder.
