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

```text
Network: 5G Private Network
Deployment: Rel-16 based
Band: n79
RU frequency range: 4720 MHz - 4920 MHz
Channel bandwidth: 100 MHz
Primary PLMN: 450-40
Primary ARFCN: 717216
Approximate center frequency: 4758.24 MHz
GSCN: 8720
PCI candidates: 1002, 1003, 1004
Confirmed PCI / Cell ID: 1003
Confirmed SSB index: 1
Confirmed common SCS: 30 kHz
Confirmed k_SSB: 20
```

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
- data/result/log paths
- figure save defaults

The official SSB capture duration is controlled by:

```matlab
captureDuration = seconds((framesPerCapture + 1)*10e-3);
```

## Figure Saving

Interactive scripts display figures by default. Add `"SaveFigures",true` to save generated figures under `outputs/figures/<capture-file-name>/`.

```matlab
run1_capture_ssb_using_sdr("SaveFigures",true)
run2_recover_mib_sib1_with_figures("SaveFigures",true)
run2_recover_mib_sib1_from_data("SaveFigures",true)
```

Optional arguments:

```matlab
"FigureDir","outputs/figures/custom"
"FigureFormat","png"   % png, fig, or both
"CloseFiguresAfterRun",true
```

To avoid typing the capture path each time, edit the user settings near the
top of the run scripts:

```matlab
% run2_recover_mib_sib1_with_figures.m
configuredCaptureFile = "data/61.44_260507.mat";

% run2_recover_mib_sib1_from_data.m
configuredDataFiles = "data/61.44_260507.mat";
```

Saved figure groups:

- `mib_sib1_*.png`: MathWorks receiver-flow figures such as spectrogram, correlations, constellations, and resource grids
- `csi_*.png`: project-added DM-RS CSI figures for sparse CSI magnitude/phase diagnostics

CSI figures show:

- sparse grid magnitude in dB
- sparse grid phase in radians
- magnitude over DM-RS reference RE order
- unwrapped phase over DM-RS reference RE order

New SDR captures are named:

```text
data/capturedWaveform_<timestamp>.mat
```

GSCN, band, gain, and channel mapping remain inside the MAT file metadata.

## CSI Definition

The project currently stores sparse LS CSI from DM-RS reference signals.

```matlab
H_DMRS = Y_DMRS ./ X_DMRS;
```

`Y_DMRS` is extracted from the received resource grid at the official example's DM-RS indices.

`X_DMRS` is generated using the official example's selected DM-RS configuration.

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

## Verified Captures

Current saved captures under `data/`:

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
```

## Interpretation Rules

- Treat PBCH DM-RS CSI as the default robust CSI product.
- Treat SIB1 PDSCH DM-RS CSI as an additional wider allocation CSI product when SIB1 recovery succeeds.
- Do not treat current results as CSI-RS-based CSI.
- CSI-RS extraction requires gNB CSI-RS configuration, which is not currently available in the log.
- Do not reintroduce CIR/PDP unless explicitly requested. Current project scope is CSI-only.

## Related Files

```text
config/default_config.m
run1_capture_ssb_using_sdr.m
run2_recover_mib_sib1_with_figures.m
run2_recover_mib_sib1_from_data.m
src/NRCellSearchMIBAndSIB1RecoveryExample.m
src/recoverMibSib1FromCapture.m
```
