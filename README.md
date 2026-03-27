# [Project Brief] Passive 5G NR Downlink CSI/CIR Extraction using MATLAB 5G Toolbox & USRP B210 (+ GPSDO)

## 1. Project Goal

The objective is to build a MATLAB-based passive receiver pipeline for Over-the-Air (OTA) capture of a 5G NR downlink signal from a private 5G network in n79 band using a USRP B210 with GPSDO.

This is **not** a UE attachment or user-data decoding project.  
This project only aims to:

1. capture raw downlink IQ samples,
2. perform blind or semi-guided cell search,
3. detect SSB and synchronize the waveform,
4. identify usable reference signals,
5. estimate frequency-domain channel response (CSI),
6. transform CSI into delay-domain CIR,
7. export the results in a clean dataset format for later AI training.

The extracted CIR/CSI will later be used for:
- UE location prediction using DNN / LSTM / Transformer,
- comparison with ns-o-ran and Sionna-RT simulation outputs,
- possible cross-validation against digital twin / ray-tracing results.

Because of this, phase stability, repeatable timing, metadata logging, and clean export are important.

---

## 2. Known Environment

### Target Network
- 5G Private Network
- Rel-16-based deployment
- Band: n79
- RU frequency range: 4720 MHz - 4920 MHz

### Known Candidate Cell Information
Use the following as the primary search target:
- PLMN: 450-40
- ARFCN: 717216
- Approximate center frequency: 4758.24 MHz
- PCI candidates: 1002, 1003, 1004

These values should be used to support a **semi-guided search** mode, while keeping a blind-search mode available.

### SDR Hardware
- NI USRP B210
- GPSDO available and should be used if supported in the actual SDR configuration
- USB 3.0 host interface
- n79-capable antenna
- partial-band capture only (not full 100 MHz)

### Assumptions
- Default SCS assumption: 30 kHz
- Must allow fallback testing of 60 kHz and 15 kHz
- Capture bandwidth: around 30-40 MHz
- Sample rate candidates: 30.72 MSps or 61.44 MSps
- Capture duration per burst: at least 20-30 ms

---

## 3. Required MATLAB Toolboxes

- **5G Toolbox**
  - Required for NR-specific processing such as `nrCellSearch`, `nrOFDMDemodulate`, and `nrChannelEstimate`.
- **Communications Toolbox**
  - Required as a base dependency for communication-system signal processing and SDR-related workflows.
- **Communications Toolbox Support Package for USRP Radio**
  - Required for MATLAB to detect and control the USRP B210, typically via `comm.SDRuReceiver`, and capture OTA IQ samples.
- **Signal Processing Toolbox**
  - Required for FFT/IFFT-based CSI-to-CIR conversion, filtering, spectrum analysis, and windowing functions such as Hamming or Kaiser.

---

## 4. Important Constraints

1. The B210 cannot reliably capture the full 100 MHz channel bandwidth of the private network in this setup.
2. Therefore, the CIR produced by this pipeline should be treated as an **effective CIR over the captured partial bandwidth**, not necessarily the full-band ground-truth CIR.
3. The implementation should prioritize:
   - robustness,
   - debuggability,
   - reproducibility,
   - metadata completeness.
4. User payload decoding is out of scope.
5. The implementation should focus on synchronization and channel estimation only.

---

## 5. Implementation Tasks

### Step 1. SDR Initialization and IQ Capture
Implement MATLAB code to:
- configure the USRP B210 receiver,
- set center frequency using ARFCN conversion,
- set sample rate, gain, and frame size,
- set clock/time source to GPSDO if supported by the configuration,
- capture raw complex IQ samples for 20-30 ms or more,
- save raw IQ and capture metadata.

Requirements:
- create a helper function that converts NR-ARFCN to frequency in Hz,
- allow easy manual override of center frequency,
- log:
  - center frequency,
  - sample rate,
  - gain,
  - capture duration,
  - timestamp,
  - GPSDO/clock settings,
  - overflow/underflow flags if available.

### Step 2. Blind / Semi-Guided Cell Search and Synchronization
Implement:
- blind cell search using `nrCellSearch`,
- support for optional PCI candidate filtering using known PCI values [1002, 1003, 1004],
- coarse timing estimation,
- CFO estimation and correction,
- synchronized waveform generation.

Requirements:
- if blind search fails, retry with:
  1. alternate SCS values,
  2. manual center frequency refinement,
  3. PCI-guided search logic if possible.
- store:
  - detected PCI,
  - timing offset,
  - CFO estimate,
  - search metric / detection confidence.

### Step 3. OFDM Demodulation and Resource Grid Reconstruction
Implement:
- `nrCarrierConfig`,
- waveform alignment,
- `nrOFDMDemodulate`,
- generation of the frequency-domain resource grid.

Requirements:
- carrier configuration must be parameterized,
- SCS must be configurable,
- FFT size and carrier settings must be logged.

### Step 4. Reference-Signal Strategy
Because full PDSCH scheduling information may not be known, implement the channel-estimation path in stages:

#### Stage 4A. Initial robust path
Start from the most robust and practical reference-signal path available after synchronization.
Prefer simpler synchronization-linked reference signals first if needed.

#### Stage 4B. DMRS-based path
If PBCH DMRS or PDSCH DMRS can be identified reliably, estimate CSI using them.

Important:
- Do not assume full network-side scheduling knowledge is available.
- Code should clearly separate:
  - blind synchronization logic,
  - reference-signal extraction logic,
  - channel-estimation logic.

### Step 5. Channel Estimation (CSI)
Implement Least-Squares channel estimation.

Target output:
- frequency-domain complex channel response:
  \[
  \hat{H}(k,l)
  \]

Requirements:
- use `nrChannelEstimate` if practical,
- otherwise allow custom LS estimation:
  \[
  \hat{H}(k,l)=\frac{Y(k,l)}{X(k,l)}
  \]
- interpolate sparse channel estimates over frequency and/or time if appropriate,
- save:
  - raw sparse estimates,
  - interpolated CSI,
  - valid reference indices.

### Step 6. CIR Transformation
Transform CSI to CIR using IFFT.

Target output:
\[
h(\tau)=\mathrm{IFFT}(\hat{H}(f))
\]

Requirements:
- allow optional windowing before IFFT (Hamming or Kaiser),
- implement optional zero-padding,
- compute:
  - complex CIR,
  - CIR magnitude,
  - Power Delay Profile (PDP),
- include a simple thresholding method to suppress weak taps/noise-floor components.

Important:
- clearly document that the resulting CIR is derived from the captured partial bandwidth.

### Step 7. Data Structuring and Export
Save all important outputs to `.mat` and optionally `.h5`.

The exported dataset should include:
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

The structure must be easy to load from Python later.

### Step 8. Visualization and Diagnostics
At the end of the script, generate plots for:
- spectrum of the raw captured signal,
- synchronization metric or cell-search metric,
- CSI magnitude over subcarriers,
- CIR magnitude,
- PDP.

The script should also print a short summary:
- success/failure of cell search,
- detected PCI,
- selected SCS,
- applied CFO correction,
- output file path.

---

## 6. Coding Guidelines

- Use modular functions whenever possible.
- Include detailed comments explaining which MATLAB 5G Toolbox function is being used and why.
- Include fallback logic and defensive error handling.
- If a function is unavailable or unsuitable in the local MATLAB version, document the assumption and provide a compatible alternative implementation path.
- Separate the pipeline into:
  1. SDR capture,
  2. synchronization,
  3. resource-grid generation,
  4. reference-signal extraction,
  5. channel estimation,
  6. CIR conversion,
  7. export and visualization.

---

## 7. Expected Deliverables

Please generate:
1. a main MATLAB script,
2. helper functions,
3. a clean configuration section,
4. comments describing how to switch:
   - ARFCN,
   - center frequency,
   - SCS,
   - sample rate,
   - gain,
   - capture duration.

The code should be written for clarity and first-pass experimental success, not for production optimization.

---

## 8. Notes for Interpretation

- This is a passive downlink measurement experiment.
- The purpose is channel observation, not protocol-complete 5G UE behavior.
- Since only partial bandwidth is captured with B210, the resulting CIR should be interpreted as partial-band effective CIR.
- The first milestone is:
  1. successful IQ capture,
  2. successful SSB detection,
  3. stable synchronization,
  4. usable CSI,
  5. physically plausible CIR / PDP.

your_workspace/
├── AGENTS.md
├── README.md
├── run_passive_nr_capture.m
├── config/
│   └── default_config.m
├── src/
│   ├── nrArfcnToHz.m
│   ├── initB210Receiver.m
│   ├── captureIQ.m
│   ├── runCellSearch.m
│   ├── correctCFO.m
│   ├── buildResourceGrid.m
│   ├── estimateCSI.m
│   ├── csiToCir.m
│   ├── exportDataset.m
│   └── plotDiagnostics.m
├── outputs/
│   ├── raw_iq/
│   ├── processed/
│   ├── figures/
│   └── logs/
└── tests/
    ├── test_nrArfcnToHz.m
    ├── test_csiToCir.m
    └── test_exportDataset.m