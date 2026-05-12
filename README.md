# 5G Channel Sounding

MATLAB 5G Toolbox 공식 예제 흐름으로 실제 5G private network downlink IQ를 SDR로 캡처하고, SSB/MIB/SIB1 recovery 뒤 CSI를 저장하는 프로젝트입니다.

현재 저장하는 CSI는 PBCH DM-RS, SIB1 PDSCH DM-RS, 그리고 TRS/NZP CSI-RS 후보 기반 sparse LS CSI입니다. CSI-RS 결과는 아직 gNB의 exact CSI-RS resource mapping이 확인되지 않았으므로 confirmed CSI-RS가 아니라 candidate result로 해석해야 합니다.

## Requirements

- MATLAB
- 5G Toolbox
- Communications Toolbox
- Communications Toolbox Support Package for USRP Radio
- Signal Processing Toolbox

## Before Running

먼저 장비 profile을 고릅니다.

```text
config/b210_config.m
config/x310_config.m
```

X310을 쓸 때는 [config/x310_config.m](config/x310_config.m)을 확인하세요.

```matlab
overrides.radio.serialNum = '';   % empty: first discovered X310 IP
overrides.radio.gain = 25;
overrides.radio.channelMapping = 1;
overrides.ssbCapture.sampleRate = 184.32e6;
```

자동 discovery가 안 되거나 X310이 여러 대면 `overrides.radio.serialNum`에 X310 IP 주소를 넣으세요. 이름은 기존 코드 호환 때문에 `serialNum`이지만, X300/X310에서는 `DeviceAddress`/`IPAddress`로 사용됩니다.

현재 튜닝 기준:

```text
Band: n79
GSCN: 8720
UE-observed / SSB ARFCN: 717216
SSB / GSCN capture frequency: 4758.24 MHz
CSV cell-physical nr-arfcn-dl/ul: 718000
Known PCI: 1003
Channel bandwidth: 100 MHz deployment
```

`717216`은 UE 관리페이지와 `ssb_config.csv`의 SSB ARFCN입니다. `718000`은 DU CSV의 별도 `nr-arfcn-dl/ul` 값이므로 SDR 튜닝값으로 바로 바꾸지 마세요.

## Run

MATLAB에서 프로젝트 폴더로 이동합니다.

```matlab
cd('/home/jinsub/channel/5g_channel_sounding')
```

X310으로 새 캡처를 뜹니다.

```matlab
run1_capture_ssb_using_sdr("Config","config/x310_config.m","SaveFigures",true)
```

B210으로 캡처하려면 profile만 바꿉니다.

```matlab
run1_capture_ssb_using_sdr("Config","config/b210_config.m","SaveFigures",true)
```

캡처가 끝나면 출력된 MAT 파일 경로를 run2에 넣습니다.

```matlab
run2_recover_mib_sib1_from_data( ...
    "outputs/1_IQcapture/capturedWaveform_x310_YYMMDD_HHMMSS.mat", ...
    "Config","config/x310_config.m", ...
    "SaveFigures",true)
```

기존 B210 캡처를 분석하려면:

```matlab
run2_recover_mib_sib1_from_data( ...
    "outputs/1_IQcapture/61.44_260507.mat", ...
    "Config","config/b210_config.m", ...
    "SaveFigures",true)
```

DU CSV와 복구 결과를 비교합니다.

```matlab
run3_validate_recovery_against_du_config
```

## Outputs

```text
outputs/1_IQcapture/                         raw IQ capture MAT files
outputs/2_processed/*_mib_sib1_recovery.mat  recovery and CSI results
outputs/2_processed/figures/<capture>/        saved figures
outputs/3_validation/                         DU config validation reports
```

CSI는 recovery MAT 파일의 `recovery.csi` 아래에 저장됩니다.

```matlab
recovery.csi.pbchDmrsLs
recovery.csi.pdschDmrsLs
recovery.csi.csirsCandidate
```

## Tips

- X310 + UBX-160은 현재 `184.32 MS/s` profile로 설정되어 있습니다.
- X310 캡처가 안 잡히면 먼저 IP 주소, 10GbE 연결, clock/reference 상태, RX 포트, gain을 확인하세요.
- 캡처 주파수는 UE에서 본 `717216 / 4758.24 MHz` 기준입니다.
- CSI-RS는 아직 후보 추출입니다. 확정 결과로 쓰려면 gNB의 CSI-RS row, port, CDM, slot offset, RB allocation, scrambling ID가 필요합니다.
- 자세한 배경은 [docs/resource.md](docs/resource.md), 전체 처리 흐름은 [docs/sdr_capture_to_csi_pipeline.md](docs/sdr_capture_to_csi_pipeline.md)를 보세요.
