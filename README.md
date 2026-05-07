# 5G Channel Sounding

MATLAB 5G Toolbox 공식 예제를 기준으로, 실제 5G private network downlink 신호를 수신하고 SSB/MIB/SIB1 복구 및 DM-RS 기반 CSI를 저장하는 프로젝트입니다.

목표는 공식 예제 흐름으로 raw IQ waveform을 캡처하고, SSB/MIB/SIB1 복구를 수행한 뒤, PBCH DM-RS 및 SIB1 PDSCH DM-RS 기반 CSI를 얻는 것입니다.

## Quick Start

0. MATLAB에서 프로젝트 폴더로 이동합니다.

```matlab
cd('/home/jinsub/channel/5g_channel_sounding')
```

1. SSB를 SDR로 캡처하고 공식 예제와 같은 resource grid figure를 확인합니다.

```matlab
run1_capture_ssb_using_sdr
```

figure를 파일로 저장하려면:

```matlab
run1_capture_ssb_using_sdr("SaveFigures",true)
```

2. 저장된 캡처로 MIB/SIB1 recovery를 figure와 함께 실행합니다.

```matlab
run2_recover_mib_sib1_with_figures
```

분석할 파일을 코드에서 고정하려면 [run2_recover_mib_sib1_with_figures.m](run2_recover_mib_sib1_with_figures.m) 상단의 `configuredCaptureFile`을 수정합니다.

공식 예제 figure를 저장하려면:

```matlab
run2_recover_mib_sib1_with_figures("SaveFigures",true)
```

`data/*.mat` 캡처 전체를 반복 분석하고 결과를 저장합니다.

```matlab
run2_recover_mib_sib1_from_data
```

batch에서 분석할 파일 목록을 고정하려면 [run2_recover_mib_sib1_from_data.m](run2_recover_mib_sib1_from_data.m) 상단의 `configuredDataFiles`를 수정합니다.

batch 분석에서도 figure 저장이 필요하면:

```matlab
run2_recover_mib_sib1_from_data("SaveFigures",true)
```

## Main Outputs

캡처 파일은 `data/`에 저장됩니다.

```text
data/capturedWaveform_<timestamp>.mat
```

MIB/SIB1 recovery 및 CSI 결과는 `outputs/processed/`에 저장됩니다.

```text
outputs/processed/*_mib_sib1_recovery.mat
```

반복 분석 summary는 `outputs/logs/`에 저장됩니다.

```text
outputs/logs/mib_sib1_batch_*.mat
```

저장된 figure는 `outputs/figures/` 아래에 저장됩니다.

```text
outputs/figures/<capture-file-name>/*.png
```

`SaveFigures`를 켜면 공식 예제 figure와 함께 CSI figure도 저장됩니다.

```text
mib_sib1_*.png
csi_*.png
```

## CSI Fields

Recovery 결과 파일을 로드하면 `recovery.csi` 아래에 CSI가 저장됩니다.

```matlab
load('outputs/processed/61.44_260507_mib_sib1_recovery.mat')
recovery.csi.pbchDmrsLs
recovery.csi.pdschDmrsLs
```

`pbchDmrsLs`는 PBCH DM-RS 기반 sparse LS CSI입니다. SSB/MIB 복구 단계에서 생성됩니다.

`pdschDmrsLs`는 SIB1 PDSCH DM-RS 기반 sparse LS CSI입니다. SIB1 recovery가 성공한 캡처에서만 생성됩니다.

CSI figure는 PBCH DM-RS CSI와 PDSCH DM-RS CSI의 sparse grid magnitude/phase 및 reference RE 순서별 magnitude/phase를 보여줍니다.

## Project Structure

```text
5g_channel_sounding/
├── README.md
├── resource.md
├── config/
│   └── default_config.m
├── data/
│   └── *.mat
├── outputs/
│   ├── processed/
│   ├── logs/
│   └── figures/
├── run1_capture_ssb_using_sdr.m
├── run2_recover_mib_sib1_with_figures.m
├── run2_recover_mib_sib1_from_data.m
└── src/
    ├── NRCellSearchMIBAndSIB1RecoveryExample.m
    ├── recoverMibSib1FromCapture.m
    ├── hSDRReceiver.m
    ├── hSDRBase.m
    ├── hSynchronizationRasterInfo.m
    └── official MathWorks helper files
```

## Configuration

공식 예제 기반 SSB/MIB/SIB1/CSI 흐름의 주요 설정은 [config/default_config.m](config/default_config.m)에 있습니다.

기본 타겟은 다음과 같습니다.

```text
Band: n79
GSCN: 8720
Center frequency: 4758.24 MHz
Sample rate: 61.44 MS/s for SSB capture
Capture duration: (framesPerCapture + 1) x 10 ms
New capture filename: capturedWaveform_<timestamp>.mat
Known PCI: 1003
Channel bandwidth: 100 MHz deployment
```

상세 배경, 값의 출처, CSI 해석 기준은 [resource.md](resource.md)를 확인하세요.
