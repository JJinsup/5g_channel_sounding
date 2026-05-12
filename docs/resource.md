# Resource Notes

이 파일은 `README.md`에서 제외한 세부 환경값, 공식 예제 기준, CSI 해석 기준을 정리합니다. 실행 명령어 중심 안내는 `README.md`를 봅니다.

## Project Goal

이 프로젝트는 MATLAB 5G Toolbox 공식 예제를 기준으로 실제 5G private network downlink 신호를 passive 수신하고, 아래 결과를 저장하는 것을 목표로 합니다.

- raw IQ waveform capture through `run1_capture_ssb_using_sdr.m`
- SSB detection
- MIB/SIB1 recovery
- PBCH DM-RS 기반 CSI
- SIB1 PDSCH DM-RS 기반 CSI
- 반복 측정 summary

이 프로젝트는 아래를 목표로 하지 않습니다.

- UE attach
- NAS/RRC procedure 구현
- user-data decoding
- full UE modem 구현
- uplink/transmit 실험

## Known Environment

`5g_NW_config/*.csv`를 기준으로 확인한 실제 특화망 값과, 캡처/receiver에서 확인한 값을 분리해서 기록한다.

```text
Network: 5G Private Network
Deployment: Rel-16 based
Band: n79
Channel bandwidth: 100 MHz
UE-observed / SSB ARFCN: 717216
UE-observed / SSB frequency: 4758.24 MHz
CSV cell-physical nr-arfcn-dl/ul: 718000
CSV cell-physical frequency equivalent: 4770.00 MHz
Nominal 30 kHz carrier grid: 273 RB
CSV ssb-loc-arfcn: 717216
SSB / GSCN capture frequency used by run1: 4758.24 MHz
GSCN used by run1: 8720
Primary PLMN used by project: 450-40
CSV cell IDs / PCIs: 1001, 1002, 1003, 1004
Observed PCI candidates near current capture: 1002, 1003, 1004
Confirmed PCI / Cell ID: 1003
Confirmed SSB index: 1
Confirmed common SCS: 30 kHz
Confirmed k_SSB: 20
```

`717216` is the value observed from the UE page and also appears in `ssb_config.csv` as `ssb-loc-arfcn`. `718000` appears separately in `cell-physical-conf-idle.csv` as `nr-arfcn-dl` and `nr-arfcn-ul`. Treat these as two distinct DU/export fields until the vendor meaning is confirmed; do not replace the UE-observed/tuned SSB frequency with `4770.00 MHz`.

CSV-backed radio details:

```text
Cell 1003 label: 1003-ORU3-미래관4층EPS실(남자화장실)
DL/UL SCS: 30 kHz
SSB: 30 kHz, max 8 SSBs, tx SSB count 1, position bitmap 01000000
SSB periodicity: 20 ms
SSB half frame / duration: second half / sf2
SSB frequency offset field: 8
RMSI CORESET index: 4
Initial/common DL BWP: CBW, offset 0
TDD basic config: tdd-configuration-13
TDD cell config: fr1-tdd-64-f1-6-4-4-f2-10-4-0
DL antenna count: 4tx
DL DM-RS idle config: Type A pos2, additional pos1, type1, max length len1
PDCCH: non-interleaved CCE-REG mapping, AL adaptation, DMRS scrambling ID off
SIB1: broadcast use, repetition 20 ms
SI window: slot40
```

TRS/NZP CSI-RS details confirmed by CSV are only partial:

```text
TRS periodicity: 40 slots
TRS OFDM symbols: 6, 10
TRS frequency separation: 3
CSI-RS periodicity: 40 slots
CSI-RS power control offset: +6 dB
```

The exact CSI-RS resource mapping is still not confirmed by the CSV files: scrambling ID, row number, port count, CDM type, exact RB offset/NumRB, frequency-domain allocation, and slot offset must still be treated as candidate/hypothesis values.

## MATLAB Requirements

- 5G Toolbox
- Communications Toolbox
- Communications Toolbox Support Package for USRP Radio
- Signal Processing Toolbox

The current workflow was tested with MATLAB R2025b examples copied into this project.

## Hardware Notes

```text
SDR: NI USRP B210
Default serial number: 3275420
Default channel mapping: 1
Default gain: 35 dB in project config, 60 dB in the original MathWorks live script
Default SSB capture sample rate: 61.44 MS/s
```

B210 cannot capture the full 100 MHz deployment bandwidth in this workflow. CSI should be interpreted as partial-band, reference-signal-conditioned CSI.

## Official Example Mapping

This project follows these MathWorks examples.

```text
MathWorks SSB capture example:
NRSSBCaptureUsingSDRExample

Project equivalent:
run1_capture_ssb_using_sdr.m
```

```text
MathWorks MIB/SIB1 recovery example:
NRCellSearchMIBAndSIB1RecoveryExample

Project equivalent with figures:
run2_recover_mib_sib1_with_figures.m

Project equivalent for batch processing:
run2_recover_mib_sib1_from_data.m
```

The receiver algorithm should stay aligned with the MathWorks example for:

- PSS/SSS search
- frequency offset correction
- timing alignment
- PBCH DM-RS hypothesis selection
- BCH/MIB decoding
- CORESET0/PDCCH/PDSCH/SIB1 recovery

## Configuration

`config/default_config.m` is the main configuration for the MathWorks-example-based SSB/MIB/SIB1/CSI workflow.

It intentionally keeps only:

- SDR identity and receive settings
- SSB capture GSCN, sample rate, and frames-per-capture
- MIB/SIB1 recovery options
- IQ capture, processed result, validation, and figure paths
- figure save defaults

The official SSB capture duration is controlled by:

```matlab
captureDuration = seconds((framesPerCapture + 1)*10e-3);
```

## Figure Saving

Interactive scripts display figures by default. Add `"SaveFigures",true` to save generated figures under `outputs/2_processed/figures/<capture-file-name>/`.

```matlab
run1_capture_ssb_using_sdr("SaveFigures",true)
run2_recover_mib_sib1_with_figures("SaveFigures",true)
run2_recover_mib_sib1_from_data("SaveFigures",true)
```

Optional arguments:

```matlab
"FigureDir","outputs/2_processed/figures/custom"
"FigureFormat","pdf"   % pdf, png, fig, or both
"CloseFiguresAfterRun",true
```

To avoid typing the capture path each time, edit the user settings near the
top of the run scripts:

```matlab
% run2_recover_mib_sib1_with_figures.m
configuredCaptureFile = "outputs/1_IQcapture/61.44_260507.mat";

% run2_recover_mib_sib1_from_data.m
configuredDataFiles = "outputs/1_IQcapture/61.44_260507.mat";
```

Saved figure groups:

- `figures.pdf`: MathWorks receiver-flow figures plus project-added DM-RS/CSI-RS-candidate CSI figures as one multipage PDF
- `mib_sib1_*.png` and `csi_*.png`: separate files when `"FigureFormat","png"` is selected

CSI figures show:

- sparse grid magnitude in dB
- sparse grid phase in radians
- magnitude over reference RE order
- unwrapped phase over reference RE order

New SDR captures are named:

```text
outputs/1_IQcapture/capturedWaveform_<timestamp>.mat
```

GSCN, band, gain, and channel mapping remain inside the MAT file metadata.

## CSI Definition

The project currently stores sparse LS CSI from DM-RS reference signals and a hypothesis-based TRS/NZP CSI-RS candidate.

```matlab
H_DMRS = Y_DMRS ./ X_DMRS;
H_CSIRS = Y_CSIRS ./ X_CSIRS;
```

`Y_DMRS` is extracted from the received resource grid at the official example's DM-RS indices.

`X_DMRS` is generated using the official example's selected DM-RS configuration.

`Y_CSIRS` and `X_CSIRS` are generated from the candidate `nrCSIRSConfig` assumptions in `docs/trs_nzp_csirs_candidate.md`. Treat this as candidate extraction until exact gNB CSI-RS resource mapping is confirmed.

### PBCH DM-RS CSI

Stored at:

```matlab
recovery.csi.pbchDmrsLs
```

Meaning:

- source: PBCH DM-RS
- available after SSB/MIB recovery
- default valid reference RE count: 144
- sparse grid size: 240 x 4 SSB grid
- uses official detected `NCellID`, `ibar_SSB`, and `ssbIndex`

Important fields:

```matlab
recovery.csi.pbchDmrsLs.indices
recovery.csi.pbchDmrsLs.rxSymbols
recovery.csi.pbchDmrsLs.txSymbols
recovery.csi.pbchDmrsLs.lsEstimate
recovery.csi.pbchDmrsLs.sparseGrid
recovery.csi.pbchDmrsLs.referenceMask
recovery.csi.pbchDmrsLs.officialChannelGrid
recovery.csi.pbchDmrsLs.noiseVariance
```

### SIB1 PDSCH DM-RS CSI

Stored at:

```matlab
recovery.csi.pdschDmrsLs
```

Meaning:

- source: SIB1 PDSCH DM-RS
- available only when DCI/PDSCH/SIB1 recovery succeeds
- observed valid reference RE count in current captures: 612
- sparse grid size in current captures: 576 x 14 monitoring slot grid
- uses official decoded DCI/PDSCH configuration

Important fields:

```matlab
recovery.csi.pdschDmrsLs.indices
recovery.csi.pdschDmrsLs.rxSymbols
recovery.csi.pdschDmrsLs.txSymbols
recovery.csi.pdschDmrsLs.lsEstimate
recovery.csi.pdschDmrsLs.sparseGrid
recovery.csi.pdschDmrsLs.referenceMask
recovery.csi.pdschDmrsLs.officialChannelGrid
recovery.csi.pdschDmrsLs.noiseVariance
recovery.csi.pdschDmrsLs.carrier
recovery.csi.pdschDmrsLs.pdsch
```

### TRS/NZP CSI-RS Candidate CSI

Stored at:

```matlab
recovery.csi.csirsCandidate
```

Meaning:

- source: TRS/NZP CSI-RS candidate
- available after run2 builds the common OFDM grid
- uses `nrCSIRSConfig`, `nrCSIRSIndices`, `nrCSIRS`, and `nrChannelEstimate` following the MathWorks CSI-RS example flow
- CSV-confirmed values: symbols `[6 10]`, period 40 slots, power offset +6 dB, full-CBW BWP
- current assumptions: row 1, density `three`, NID = detected PCI 1003
- current scan: unresolved slot offset and subcarrier location candidates are scored before extraction
- candidate RE count is run/profile dependent; check `recovery.csi.csirsCandidate.validRefReCount` and the figure title for the actual result

Important fields:

```matlab
recovery.csi.csirsCandidate.assumptions
recovery.csi.csirsCandidate.csirs
recovery.csi.csirsCandidate.txSymbols
recovery.csi.csirsCandidate.rxSymbols
recovery.csi.csirsCandidate.lsEstimate
recovery.csi.csirsCandidate.sparseGrid
recovery.csi.csirsCandidate.referenceMask
recovery.csi.csirsCandidate.activeSlots
```

## Verified Captures

Current saved captures under `outputs/1_IQcapture/`:

```text
30.72_260507.mat
61.44_260507.mat
```

Batch verification result:

```text
15.36 MS/s:
  PCI: 1003
  BCH CRC: 0
  SIB1: not available
  Reason: sample rate too low for CORESET0
  PBCH DM-RS CSI refs: 144
  PDSCH DM-RS CSI refs: N/A

30.72 MS/s:
  PCI: 1003
  BCH CRC: 0
  DCI CRC: 0
  SIB1 CRC: 0
  PBCH DM-RS CSI refs: 144
  PDSCH DM-RS CSI refs: 612

61.44 MS/s:
  PCI: 1003
  BCH CRC: 0
  DCI CRC: 0
  SIB1 CRC: 0
  PBCH DM-RS CSI refs: 144
  PDSCH DM-RS CSI refs: 612
  TRS/NZP CSI-RS candidate CSI refs: run/profile dependent
```

## Interpretation Rules

- Treat PBCH DM-RS CSI as the default robust CSI product.
- Treat SIB1 PDSCH DM-RS CSI as an additional wider allocation CSI product when SIB1 recovery succeeds.
- Treat `csirsCandidate` as hypothesis-based TRS/NZP CSI-RS candidate CSI, not confirmed gNB CSI-RS until exact resource mapping is verified.
- Confirmed CSI-RS extraction still requires exact gNB CSI-RS resource configuration.
- Do not reintroduce CIR/PDP unless explicitly requested. Current project scope is CSI-only.

## Related Files

```text
config/default_config.m
run1_capture_ssb_using_sdr.m
run2_recover_mib_sib1_with_figures.m
run2_recover_mib_sib1_from_data.m
src/NRCellSearchMIBAndSIB1RecoveryExample.m
src/recoverMibSib1FromCapture.m
src/extractCsirsCandidateCsi.m
```
