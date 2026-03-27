# Codex Handoff: Passive 5G NR CSI/CIR Pipeline State

This document is a practical handoff for the current workspace state as of `2026-03-26`.

It is written for the next Codex agent that needs to continue work without rediscovering the pipeline, the current assumptions, and the recent debugging history.

## 1. Project Intent

This repository is a **passive 5G NR downlink measurement** project using:

- MATLAB
- 5G Toolbox
- USRP B210
- optional GPSDO later

It is **not** a UE / protocol stack / RRC / NAS / PDSCH decode project.

The actual goal is:

1. capture raw OTA IQ
2. synchronize to the NR downlink
3. find a usable reference-signal path
4. estimate CSI
5. convert CFR/CSI into a partial-band CIR
6. export data cleanly for later AI / simulation comparison

Important framing:

- The CIR here is currently a **partial-band effective CIR**
- It should **not** be treated as full-band ground-truth CIR
- The current reference path is **PBCH DM-RS based**

## 2. Current High-Level Status

Current state in one sentence:

`Raw capture and PBCH DM-RS extraction work reasonably well, but precise physically trustworthy path-delay interpretation is still not solved.`

What is working:

- B210 capture
- raw IQ save
- semi-guided PCI/SCS search
- timing correction
- CP-based CFO correction
- OFDM demodulation
- PBCH DM-RS extraction
- sparse CSI inspection
- figure/log export
- batch analysis over all raw captures

What is still unstable / under active investigation:

- precise synchronization quality
- per-symbol phase consistency
- whether the current PBCH-DMRS-derived CFR is good enough for trustworthy path-delay interpretation
- how much of the remaining CIR spread is real multipath vs artifact

## 3. Main Entry Points

### 3.1 Capture

- [run_passive_nr_capture.m](/home/jinsub/channel_sounding/run_passive_nr_capture.m)

Use this to perform live SDR capture and save raw IQ + first-pass capture diagnostics.

### 3.2 Single / targeted offline CIR analysis

- [run_offline_cir_analysis.m](/home/jinsub/channel_sounding/run_offline_cir_analysis.m)

Current behavior:

- with no input, it analyzes two hardcoded representative files
- with an input path or list, it analyzes those files
- internally uses the current official offline path:
  - sync/grid
  - PBCH DM-RS analysis
  - interpolation
  - selected-symbol CFR
  - CFR -> CIR
  - export + diagnostics figure

### 3.3 Batch analysis over all captures

- [run_offline_cir_analysis_all.m](/home/jinsub/channel_sounding/run_offline_cir_analysis_all.m)

Current behavior:

- scans `outputs/raw_iq/capture_*.mat`
- processes every file
- reads capture duration from raw MAT metadata
- splits summaries by duration bucket such as `10ms`, `15ms`
- saves duration-specific summary MAT files into `outputs/logs/<durationBucket>/`

## 4. Core Configuration

Main config:

- [config/default_config.m](/home/jinsub/channel_sounding/config/default_config.m)

Current notable defaults:

- center frequency target from ARFCN `717216`
- resolved center frequency near `4758.24 MHz`
- sample rate `15.36e6`
- gain `35 dB`
- capture duration `15 ms`
- default SCS `30 kHz`
- fallback SCS `[60 15]`
- PCI candidates `[1003 1004 1002]`
- CFO correction enabled
- PBCH phase refinement enabled
- CIR window: `hamming`
- zero-pad factor: `4`
- tap threshold: `-20 dB`

Current practical meaning:

- the project is presently running at a **lower sample-rate first-pass validation setting**
- not yet at the more ambitious `30.72 / 61.44 MSps` target described in the README

## 5. Raw Capture Path

### 5.1 SDR initialization

- [src/initB210Receiver.m](/home/jinsub/channel_sounding/src/initB210Receiver.m)

Current behavior:

- creates `comm.SDRuReceiver`
- applies:
  - center frequency
  - master clock rate
  - decimation factor
  - gain
  - samples per frame
  - output datatype
  - channel mapping
- tries to set:
  - `ClockSource`
  - `PPSSource`

Current default is still internal clock / PPS.

### 5.2 Capture and save

- [src/captureIQ.m](/home/jinsub/channel_sounding/src/captureIQ.m)

Current behavior:

- reads frames from the radio
- concatenates valid IQ
- logs overrun flags
- builds metadata
- prepares raw output path
- prepares spectrum figure path

Important raw metadata fields saved in capture results:

- `centerFrequencyHz`
- `sampleRate`
- `gain`
- `requestedDurationMs`
- `samplesCaptured`
- `validFrameCount`
- `overflowFlags`
- `overflowDetected`
- `clockSource`
- `ppsSource`
- timestamps

### 5.3 Raw capture MAT structure

Current live capture script saves:

- variable: `results`

Inside `results`:

- `results.config`
- `results.runtime`
- `results.capture`
- `results.diagnostics`
- `results.runInfo`

Inside `results.capture`:

- `iq`
- `metadata`
- `outputMatPath`
- `outputFigurePath`

This matters because some old scripts assumed a top-level `metadata`, but the actual live capture format is typically `results.capture.metadata`.

## 6. Offline Processing Path

The current offline path is:

1. load raw capture
2. cell search
3. timing correction
4. CFO correction
5. optional manual residual correction
6. OFDM demodulation
7. optional PBCH phase-based residual timing refinement
8. PBCH DM-RS extraction
9. PBCH per-symbol phase alignment
10. sparse CSI interpolation
11. choose one CFR symbol
12. CFR -> CIR
13. export MAT + figures

### 6.1 Sync and grid

- [run_offline_sync_and_grid.m](/home/jinsub/channel_sounding/run_offline_sync_and_grid.m)

Current raw input expectation:

- loads `results` from raw capture MAT
- expects `results.capture`

Current outputs inside `syncGridResult`:

- `captureFile`
- `captureMetadata`
- `searchResult`
- `syncResult`
- `cfoResult`
- `initialPbchResult`
- `manualResidualSyncResult`
- `phaseRefinementResult`
- `residualSyncResult`
- `gridResult`

### 6.2 Cell search

- [src/runCellSearch.m](/home/jinsub/channel_sounding/src/runCellSearch.m)

Important note:

- this is **not** true blind `nrCellSearch`
- current implementation uses:
  - `nrPSS`
  - `nrSSS`
  - `nrTimingEstimate`

It ranks candidate `(PCI, SCS)` combinations by a combined timing metric.

Implication:

- current `detectedPCI` is “best semi-guided candidate by score”
- not a full standards-complete blind search result

### 6.3 CFO correction

- [src/correctCFO.m](/home/jinsub/channel_sounding/src/correctCFO.m)

Current method:

- CP correlation

This is a practical first-pass estimator, not a final precision solution.

### 6.4 Grid build

- [src/buildResourceGrid.m](/home/jinsub/channel_sounding/src/buildResourceGrid.m)

Current behavior:

- builds `nrCarrierConfig`
- calls `nrOFDMInfo`
- calls `nrOFDMDemodulate`

### 6.5 PBCH DM-RS extraction

- [src/estimatePBCHDMRSCSI.m](/home/jinsub/channel_sounding/src/estimatePBCHDMRSCSI.m)

Current behavior:

- takes the demodulated grid
- scans 240x4 candidate SSB blocks
- picks the block with strongest PBCH DM-RS energy
- extracts PBCH DM-RS
- forms LS estimate
- builds sparse 240x4 CSI block

Important practical numbers:

- total SSB block REs: `240 x 4 = 960`
- valid PBCH DM-RS REs: typically `144`
- so sparse CSI is mostly empty by construction

### 6.6 PBCH per-symbol phase alignment

- [src/applyPbchSymbolPhaseAlignment.m](/home/jinsub/channel_sounding/src/applyPbchSymbolPhaseAlignment.m)

Current behavior:

- for each PBCH DM-RS-bearing symbol
- fits `phase = a*k + b`
- derotates the symbol
- stores both raw and aligned forms

Important note:

- this logic has been heavily debugged
- it helps inspection, but it is **not yet proven** to solve all remaining CIR issues

### 6.7 Sparse CSI interpolation

- [src/interpolateSparseCSI.m](/home/jinsub/channel_sounding/src/interpolateSparseCSI.m)

Current behavior:

- takes sparse PBCH CSI
- interpolates magnitude and phase separately
- symbol-by-symbol in subcarrier direction
- no complex spline-like interpolation
- clamps edges
- identifies symbols that actually contain reference REs

Very important current design choice:

- the main CIR path **does not use the old `meanCSI` path anymore**
- it selects **one symbol**:
  - `selectedSymbolIndex`
  - `selectedSymbolCSI`

Why:

- averaging across symbols was found to reintroduce large phase artifacts
- current philosophy is closer to:
  - `selected CFR symbol -> IFFT -> CIR`

### 6.8 CFR -> CIR

- [src/csiToCir.m](/home/jinsub/channel_sounding/src/csiToCir.m)

Current behavior:

1. receive a 1D CFR vector
2. preprocess it:
   - unwrap phase
   - fit a linear phase slope on sufficiently strong bins
   - phase-flatten
   - edge trim
   - apply taper window over trusted bins
3. zero-pad to `zeroPadFactor * N`
4. IFFT
5. build several views:
   - raw CIR
   - centered CIR
   - peak-centered CIR / PDP
   - causal-style relative view

Important caveat:

- current causal view is **relative**
- not an absolute physical propagation-delay estimate
- `First significant tap = 0 ns` is a coordinate choice, not physical ToA

## 7. Current Visualization State

Main diagnostics plot:

- [src/plotCsiCirDiagnostics.m](/home/jinsub/channel_sounding/src/plotCsiCirDiagnostics.m)

Current panels typically include:

- raw sparse CSI magnitude
- PBCH phase vs subcarrier
- sparse CSI magnitude heatmap
- interpolated CSI magnitude heatmap
- valid reference RE mask
- PBCH phase offset-removed overlay
- selected-symbol CSI magnitude
- selected-symbol CSI phase
- centered CIR magnitude
- peak-centered PDP
- relative CIR view

Important recent plot conventions:

- PBCH phase panels now show **post-alignment only**
- legends were simplified to just `S2`, `S3`, `S4` if present
- relative CIR x-axis currently has been experimented with a lot and may still change
- current CIR display is **display-normalized**
  - for plotting only
  - not meant to overwrite the underlying saved CIR values

## 8. Output / Save Structure

### 8.1 Raw capture outputs

- `outputs/raw_iq/`

Typical files:

- `capture_<timestamp>_fc_<MHz>_sr_<MSps>.mat`

### 8.2 Processed outputs

- `outputs/processed/`

Current processed MAT naming:

- `<captureBaseName>_processed.mat`

### 8.3 Figures

- `outputs/figures/<durationBucket>/`

Examples:

- `outputs/figures/10ms/...`
- `outputs/figures/15ms/...`

This duration bucketing is already implemented in:

- [src/captureIQ.m](/home/jinsub/channel_sounding/src/captureIQ.m)
- [src/exportProcessedResult.m](/home/jinsub/channel_sounding/src/exportProcessedResult.m)
- [src/getDurationBucketName.m](/home/jinsub/channel_sounding/src/getDurationBucketName.m)

### 8.4 Logs / batch summaries

- `outputs/logs/`
- `outputs/logs/<durationBucket>/`

`run_offline_cir_analysis_all.m` now saves duration-split summary MAT files such as:

- `outputs/logs/10ms/offline_cir_batch_10ms_<timestamp>.mat`
- `outputs/logs/15ms/offline_cir_batch_15ms_<timestamp>.mat`

## 9. What the Current Results Mean

This is important for anyone continuing the project.

### 9.1 What the current CIR can support

The current CIR is still useful for:

- relative channel-structure comparison
- repeated-measurement consistency checks
- coarse multipath richness inspection
- partial-band baseline dataset generation

### 9.2 What the current CIR should **not** yet be trusted for

The current CIR should **not** yet be treated as trustworthy for:

- absolute path-delay estimation
- path-by-path physical interpretation at fine resolution
- direct mapping of strongest tap to real direct path
- precise ToA / ranging interpretation

### 9.3 Why not

Main reasons:

- partial bandwidth only
- PBCH DM-RS is sparse
- current search/sync is semi-guided and still imperfect
- remaining phase inconsistency likely still exists
- 7.2 MHz effective bandwidth gives only coarse delay resolution

## 10. Recent Debugging Conclusions

These are important because a lot of time was spent rediscovering them.

### 10.1 Mean-CSI averaging was a major problem

Old idea:

- interpolate per symbol
- average symbols into `meanCSI`
- IFFT

Result:

- large artificial phase curvature
- misleading CIR broadening

Current decision:

- do **not** use mean-CSI as the main CFR-to-CIR path
- use `selectedSymbolCSI` instead

### 10.2 PBCH raw sparse CSI extraction is actually decent

The main failure is **not** that PBCH DM-RS cannot be extracted.

The extraction itself is usually stable enough to continue debugging downstream.

### 10.3 The biggest remaining bottleneck is interpretability

The current question is no longer “can we get any CIR at all?”

The real question is:

`Can this PBCH-DMRS partial-band path produce a CIR that is physically interpretable enough for direct-path / reflected-path delay use?`

As of now, the answer is:

- probably **not yet**
- and possibly **not with this reference strategy alone**

## 11. Current Script Behaviors Worth Remembering

### 11.1 `run_offline_cir_analysis.m`

With no input:

- analyzes two representative captures only
- this is intentional for faster debugging

### 11.2 `run_offline_cir_analysis_all.m`

Now:

- processes all `capture_*.mat` files in `rawIqRoot`
- groups outputs by capture duration

It also tries several metadata layouts for duration extraction:

- `metadata.requestedDurationMs`
- `capture.metadata.requestedDurationMs`
- `results.metadata.requestedDurationMs`
- `results.capture.metadata.requestedDurationMs`
- filename fallback (`10ms`, `15ms`)

## 12. Known Current Friction / Broken Expectations

These are not necessarily code bugs, but they are active pain points.

1. CIR plotting has been changed many times recently and is still under refinement.
2. Relative CIR display can be visually misleading if treated as physical ToA.
3. Strongest tap can appear much later than “expected physical arrival”.
   This is currently not evidence of true absolute delay.
4. Some plot legends and titles were recently adjusted many times; verify visual output before trusting it.
5. The current phase-alignment and CFR-preprocessing choices are still experimental.

## 13. If a New Codex Continues From Here

Recommended working assumptions:

1. Treat the current pipeline as a **debuggable baseline**, not a finished measurement tool.
2. Do not revert back to mean-CSI-based CIR as the main path.
3. Be conservative about physical claims from the current CIR.
4. Keep all display normalization clearly labeled as display-only.
5. Preserve raw IQ and processed intermediate outputs.

Recommended next decision points:

1. Decide whether the current PBCH DM-RS route is good enough for the true project goal.
2. If the goal is true direct/reflected path delay interpretation, consider moving to a better CFR source rather than endlessly polishing the same PBCH route.
3. If keeping PBCH as a baseline, clearly label outputs as:
   - partial-band effective CIR
   - relative, not absolute path-delay ground truth

## 14. Minimal Mental Model of the Current Pipeline

If you remember only one simplified chain, remember this:

1. `run_passive_nr_capture`
   - capture raw IQ
   - save `results.capture`

2. `run_offline_sync_and_grid`
   - load raw capture
   - semi-guided search
   - timing correction
   - CFO correction
   - OFDM demod

3. `run_offline_pbch_dmrs_analysis`
   - pick strongest PBCH-DMRS-bearing SSB block
   - build sparse LS CSI
   - optionally phase-align per symbol

4. `interpolateSparseCSI`
   - interpolate sparse CSI
   - choose one symbol as main CFR

5. `csiToCir`
   - preprocess selected CFR
   - IFFT to partial-band effective CIR

6. `exportProcessedResult`
   - save processed MAT
   - save diagnostics figure in duration bucket

## 15. File List Most Important for Future Work

- [config/default_config.m](/home/jinsub/channel_sounding/config/default_config.m)
- [run_passive_nr_capture.m](/home/jinsub/channel_sounding/run_passive_nr_capture.m)
- [run_offline_sync_and_grid.m](/home/jinsub/channel_sounding/run_offline_sync_and_grid.m)
- [run_offline_pbch_dmrs_analysis.m](/home/jinsub/channel_sounding/run_offline_pbch_dmrs_analysis.m)
- [run_offline_cir_analysis.m](/home/jinsub/channel_sounding/run_offline_cir_analysis.m)
- [run_offline_cir_analysis_all.m](/home/jinsub/channel_sounding/run_offline_cir_analysis_all.m)
- [src/runCellSearch.m](/home/jinsub/channel_sounding/src/runCellSearch.m)
- [src/correctCFO.m](/home/jinsub/channel_sounding/src/correctCFO.m)
- [src/estimatePBCHDMRSCSI.m](/home/jinsub/channel_sounding/src/estimatePBCHDMRSCSI.m)
- [src/applyPbchSymbolPhaseAlignment.m](/home/jinsub/channel_sounding/src/applyPbchSymbolPhaseAlignment.m)
- [src/interpolateSparseCSI.m](/home/jinsub/channel_sounding/src/interpolateSparseCSI.m)
- [src/csiToCir.m](/home/jinsub/channel_sounding/src/csiToCir.m)
- [src/exportProcessedResult.m](/home/jinsub/channel_sounding/src/exportProcessedResult.m)
- [src/plotCsiCirDiagnostics.m](/home/jinsub/channel_sounding/src/plotCsiCirDiagnostics.m)

## 16. Final Honest Status

The repository is no longer in “does anything work?” territory.

It is now in:

`the pipeline runs end-to-end, but the scientific trustworthiness of the current CIR interpretation is still under active validation.`

That distinction matters.
