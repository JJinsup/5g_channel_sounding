# AGENTS.md

## Purpose

This repository implements a **passive 5G NR downlink measurement pipeline** in MATLAB using a **USRP B210** (with GPSDO when available) to extract **CSI/CIR** from OTA captures of a private 5G network in **n79**.

This project is **not** about:
- UE attachment
- NAS/RRC procedures
- user-data decoding
- protocol-complete 5G UE behavior

This project **is** about:
- raw IQ capture
- blind or semi-guided cell search
- SSB-based synchronization
- reference-signal extraction
- CSI estimation
- CSI → CIR conversion
- clean dataset export for later AI training and simulation comparison

If anything conflicts with this intent, prefer the passive measurement goal.

---

## Source of Truth

1. `README.md` is the primary project brief and scope definition.
2. `AGENTS.md` defines how to implement the project safely and consistently.
3. If there is a conflict, follow `README.md` for scope and `AGENTS.md` for coding behavior.
4. Do not silently invent requirements that are not present in the repository.

---

## Known Operating Assumptions

Use these as defaults unless the user explicitly changes them:

- Target band: **n79**
- RU operating range: **4720 MHz – 4920 MHz**
- SDR: **NI USRP B210**
- GPSDO: use when supported by local configuration
- Default SCS: **30 kHz**
- Fallback SCS: **60 kHz**, then **15 kHz**
- Partial-band capture only, not full 100 MHz
- Typical capture bandwidth target: **30–40 MHz**
- Sample-rate candidates: **30.72 MSps** or **61.44 MSps**
- Capture duration target: **20–30 ms or more**
- Primary semi-guided search target:
  - PLMN: `450-40`
  - ARFCN: `717216`
  - Approx. center frequency: `4758.24e6`
  - PCI candidates: `1002`, `1003`, `1004`

Treat the resulting CIR as a **partial-band effective CIR**, not guaranteed full-band ground truth.

---

## Top-Level Engineering Priorities

Always optimize for these, in order:

1. **Correctness**
2. **Robustness**
3. **Debuggability**
4. **Reproducibility**
5. **Metadata completeness**
6. **Clarity of code**
7. **First-pass experimental success**
8. **Performance optimization** (last)

Do not over-engineer early versions.

---

## Non-Negotiable Rules

### 1) Preserve raw data
Never discard raw IQ after processing.  
Always save raw IQ and metadata before deeper processing.

### 2) Separate pipeline stages
Keep the implementation cleanly separated into:
1. SDR capture
2. synchronization
3. grid construction
4. reference-signal extraction
5. channel estimation
6. CIR conversion
7. export
8. diagnostics

Do not merge all logic into one giant function.

### 3) Prefer transparent logic
If a built-in MATLAB function is used, comment why it is used.
If a built-in function is unavailable or version-dependent, document that clearly and provide a fallback path when practical.

### 4) Avoid pretending full scheduling knowledge exists
Do not assume full gNB-side scheduling or full PDSCH knowledge is available.
Implement a staged reference-signal strategy:
- first, the most robust synchronization-linked path
- then PBCH DMRS or other practical reference-signal path
- only then attempt more advanced DMRS-based estimation if justified

### 5) No UE/protocol stack work
Do not implement:
- UE attach
- RRC/NAS
- PDU session logic
- user-data decode
- full modem behavior

Those are explicitly out of scope.

### 6) Never hardcode a single success path
Support fallback behavior:
- alternate SCS values
- manual center-frequency override
- semi-guided PCI candidate usage
- blind-search retry mode

### 7) Fail loudly, not silently
When something cannot be reliably computed, return a warning or structured error.
Do not silently produce misleading outputs.

---

## Repository Layout and Responsibilities

### `run_passive_nr_capture.m`
Main orchestration script.

Responsibilities:
- load config
- initialize receiver
- capture IQ
- run cell search / synchronization
- build resource grid
- estimate CSI
- compute CIR
- export results
- generate diagnostic plots
- print run summary

This file should remain readable and high-level.
Keep heavy logic in `src/`.

---

### `config/default_config.m`
Central configuration entry point.

Requirements:
- all important experiment parameters must be set here or overridden from here
- avoid magic numbers elsewhere
- include comments for:
  - ARFCN
  - center frequency override
  - SCS
  - sample rate
  - capture duration
  - gain
  - GPSDO-related options
  - file export options

Prefer returning a single config struct.

---

### `src/nrArfcnToHz.m`
Convert NR-ARFCN to center frequency in Hz.

Requirements:
- deterministic
- unit-testable
- validate input range
- document assumptions clearly

---

### `src/initB210Receiver.m`
Create and configure the SDR receiver object.

Requirements:
- B210 configuration only
- centralize SDR object construction here
- set clock/time source to GPSDO if supported
- expose useful configuration values
- return both receiver object and resolved runtime parameters

Do not scatter SDR object creation across the repository.

---

### `src/captureIQ.m`
Capture raw IQ and associated metadata.

Requirements:
- return raw complex IQ
- log timing, sample rate, gain, center frequency, capture length
- record overflow/underflow indicators if available
- support burst-style capture robustly

Raw IQ should always be exportable to `outputs/raw_iq/`.

---

### `src/runCellSearch.m`
Run blind or semi-guided cell search and initial synchronization.

Requirements:
- support blind search
- support semi-guided use of known PCI candidates
- estimate timing offset
- produce a detected PCI or a structured failure result
- store detection metrics/confidence if possible

This file should not also handle export or plotting.

---

### `src/correctCFO.m`
Estimate and correct carrier frequency offset.

Requirements:
- keep logic explicit
- return corrected waveform and estimated CFO
- make it easy to disable/compare correction paths for debugging

---

### `src/buildResourceGrid.m`
Build the synchronized frequency-domain resource grid.

Requirements:
- use carrier configuration cleanly
- allow configurable SCS
- document FFT / carrier assumptions
- return grid and useful metadata for later stages

---

### `src/estimateCSI.m`
Estimate channel response from available reference signals.

Requirements:
- clearly separate:
  - reference-signal selection
  - extraction of ref indices/symbols
  - channel estimation
  - interpolation
- use `nrChannelEstimate` when appropriate
- otherwise allow explicit LS estimation path
- save both sparse and interpolated CSI when possible

Do not hide reference-signal assumptions.

---

### `src/csiToCir.m`
Convert CSI to CIR / PDP.

Requirements:
- support windowing before IFFT
- support optional zero-padding
- return:
  - complex CIR
  - CIR magnitude
  - PDP
  - delay axis if possible
- support simple thresholding of weak taps

Always document that the CIR is derived from the captured partial bandwidth.

---

### `src/exportDataset.m`
Save outputs in a format easy to load from Python later.

Required exports:
- raw IQ
- synchronized waveform
- detected PCI
- center frequency
- sample rate
- capture bandwidth
- SCS used
- timing offset
- CFO estimate
- reference-signal indices
- sparse CSI
- interpolated CSI
- CIR
- PDP
- timestamp / GPS-related metadata if available

Preferred formats:
- `.mat`
- optional `.h5`

Avoid custom obscure binary formats unless requested.

---

### `src/plotDiagnostics.m`
Generate simple, useful diagnostic plots.

Expected plots:
- raw spectrum
- cell-search / sync metric
- CSI magnitude
- CIR magnitude
- PDP

The plotting code should never be required for the core processing to succeed.

---

## Output Directory Conventions

Use these directories consistently:

- `outputs/raw_iq/`
- `outputs/processed/`
- `outputs/figures/`
- `outputs/logs/`

Do not mix raw captures and processed outputs in the same folder.

Prefer timestamped run subfolders or clearly named output prefixes.

---

## Testing Expectations

Tests live in `tests/`.

Current tests may include:
- `test_nrArfcnToHz.m`
- `test_csiToCir.m`
- `test_exportDataset.m`

Testing rules:
- add tests for deterministic helper functions
- prioritize pure-function tests
- avoid requiring live SDR hardware for basic unit tests
- if hardware-dependent behavior is unavoidable, isolate it and document it

Do not create fragile tests that depend on a specific lab setup unless clearly marked as integration tests.

---

## Implementation Style

### Code style
- use small, focused functions
- explicit inputs/outputs
- avoid hidden state
- avoid globals unless absolutely necessary
- prefer structs over long argument lists when appropriate
- name variables clearly for RF/NR meaning

### Comments
- comment the intent, not the obvious syntax
- explain why a MATLAB 5G Toolbox function is used
- call out version-sensitive behavior
- document assumptions around reference signals and synchronization

### Error handling
- use meaningful `error`, `warning`, or status structs
- include enough context for debugging
- do not swallow exceptions without explanation

---

## Search and Fallback Strategy

When cell search or synchronization fails, try in this order:

1. verify center frequency
2. retry with the configured semi-guided target
3. retry alternate SCS values
4. check capture duration / gain / sample rate assumptions
5. preserve failed-run logs and raw IQ for offline debugging

Do not “fix” failures by hardcoding a fake success.

---

## First Milestone Definition

A first-pass implementation is considered successful only if it can do all of the following:

1. capture usable IQ
2. detect SSB or produce a trustworthy failure diagnostic
3. stabilize timing/frequency synchronization
4. produce usable CSI
5. produce a physically plausible CIR/PDP
6. export results with enough metadata for later replay

This milestone matters more than optimization or feature completeness.

---

## What Not to Do

Do not:
- implement UE attach behavior
- add unsupported protocol-stack logic
- assume full-band 100 MHz capture on B210
- assume PDSCH scheduling is fully known
- delete raw IQ after processing
- hide important assumptions inside helper functions
- optimize for speed before correctness
- introduce external dependencies unless clearly justified

---

## When Unsure

If something is unclear:
1. keep the implementation conservative,
2. document the assumption,
3. make the code easy to inspect,
4. prefer a robust placeholder over a misleading “smart” solution.

When in doubt, choose the path that is easiest to debug and validate experimentally.

---

## Expected End State

The repository should produce:
- a clear MATLAB entry script,
- modular helper functions,
- reproducible outputs,
- Python-friendly exported data,
- enough diagnostics to understand why a run succeeded or failed.

The result should be a practical passive downlink CSI/CIR extraction baseline that is easy to extend later.