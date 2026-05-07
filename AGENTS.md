# AGENTS.md

Guidelines for Codex when working in this repository.

These instructions bias toward careful, minimal, verifiable changes. For trivial tasks, use judgment and avoid unnecessary ceremony.

## 1. Think Before Editing

Do not assume silently. Surface uncertainty when it affects the implementation.

Before making changes:

- State the working assumptions briefly when the task is ambiguous.
- If there are multiple reasonable interpretations, mention them and choose the smallest reversible path unless clarification is required.
- Ask a question only when the ambiguity blocks progress or could cause significant rework.
- Prefer the simpler approach when it satisfies the request.
- Push back if the requested change appears unsafe, unnecessary, or likely to make the code worse.

Do not over-plan trivial edits. For small fixes, proceed directly and verify.

## 2. Simplicity First

Write the minimum code needed to solve the requested problem.

- Do not add features that were not requested.
- Do not introduce abstractions for single-use logic.
- Do not add configurability unless the task requires it.
- Do not add broad error handling for scenarios that cannot realistically occur.
- Avoid large rewrites when a focused change is enough.
- If a solution is becoming long or complex, stop and simplify before continuing.

A good change should be easy to explain in one or two sentences.

## 3. Surgical Changes Only

Touch only the files and lines needed for the task.

When editing existing code:

- Do not refactor unrelated code.
- Do not reformat unrelated sections.
- Do not rename things unless the task requires it.
- Match the existing project style, even if a different style would be preferred.
- If unrelated dead code or bugs are noticed, mention them in the final response instead of changing them.

When your own changes create unused imports, variables, functions, or files, remove them.

Every changed line should be traceable to the user's request.

## 4. Goal-Driven Execution

Convert tasks into verifiable goals.

For non-trivial work, use this loop:

1. Identify the target behavior.
2. Make the smallest change that should achieve it.
3. Run the most relevant verification command.
4. If verification fails, inspect the failure and iterate.
5. Stop when the requested behavior is verified or when a real blocker is found.

Examples:

- "Fix the bug" means reproduce or identify the failure, patch it, then verify.
- "Add validation" means cover invalid inputs, valid inputs, and boundary cases where practical.
- "Refactor" means preserve behavior and run the existing tests before and after when feasible.

## 5. Verification

Prefer concrete verification over visual inspection.

Use the project's existing commands when available:

- Run targeted tests for the changed area first.
- Run lint/type checks if the edited files are covered by them.
- Run broader tests only when the change could affect shared behavior.
- If a command is unavailable, fails for an unrelated reason, or would be too expensive, explain that clearly.

Do not claim that something works unless it was verified or the limitation is explicitly stated.

## 6. Reporting Back

At the end of a task, summarize only what matters:

- What changed.
- Which files were changed.
- What verification was run.
- Any known limitations or follow-up issues.

Do not include long explanations unless requested.
Do not hide failed commands.
Do not claim unrelated improvements.

## 7. Repository-Specific Notes

This repository is for SDR / 5G NR / CSI-related experimentation.

When working on MATLAB or signal-processing code:

- Preserve existing experiment scripts unless the task explicitly asks to restructure them.
- Keep capture, synchronization, channel-estimation, and plotting steps separated when practical.
- Save intermediate data such as waveform, sample rate, center frequency, cell ID, SSB index, CSI-RS config, channel estimate, and noise variance when relevant.
- Avoid hard-coding site-specific RF settings unless the task explicitly asks for a quick experiment script.
- Never add transmit/OTA behavior unless explicitly requested and legally/operationally authorized.
- Prefer receive-only workflows for real 5G private-network experiments.
- Treat `run1_capture_ssb_using_sdr.m` as the MathWorks SSB-capture-style entry point.
- Treat `run2_recover_mib_sib1_with_figures.m` as the interactive MathWorks MIB/SIB1-recovery-style entry point.
- Treat `run2_recover_mib_sib1_from_data.m` as the batch/no-figure recovery entry point.

For CSI-RS work:

- Treat gNB CSI-RS configuration as required input when available.
- Do not pretend CSI-RS can be decoded blindly with full confidence without configuration.
- Clearly distinguish between:
  - SSB/PBCH-DMRS based effective channel estimates,
  - SIB1/PDSCH-DMRS based channel estimates,
  - CSI-RS based CSI.
- Preserve complex channel estimates, not only magnitude plots.
