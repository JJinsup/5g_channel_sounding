# TRS / NZP CSI-RS Candidate Parameters

이 문서는 passive SDR 기반 TRS/NZP CSI-RS 후보 검출을 위해 `5g_NW_config/*.csv`에서 확인한 값과, 아직 CSV에서 직접 확인하지 못해 현재 가정으로 둘 값을 분리해서 정리한다.

## TRS / NZP CSI-RS 후보

```text
Type: TRS / NZP CSI-RS 후보
Cell / PCI: 1003
NID 후보: 1003
SCS: 30 kHz
Carrier bandwidth: 100 MHz
Carrier grid 후보: 273 RB
BWP: CBW 전체, offset 0
CSI-RS periodicity: 40 slots
TRS periodicity: 40 slots
TRS OFDM symbols: 6, 10
TRS frequency separation: 3
CSI-RS power offset: +6 dB
```

## 아직 CSV에서 못 찾은 값

```text
TRS/CSI-RS scrambling ID
TRS/CSI-RS exact RBOffset
TRS/CSI-RS exact NumRB
CSI-RS row number
CSI-RS CDM type
CSI-RS port 수
frequency-domain allocation / subcarrier locations
common-csi-rs-index 0/1/2 mapping
```

## 현재 사용할 가정값

```text
scrambling ID = PCI = 1003
RBOffset = 0
NumRB = 273
Density = 3
SymbolLocations = [6 10]
Periodicity = 40 slots
Slot offset = unresolved, scan 0:39
Subcarrier location = unresolved, scan supported row-1 candidates
Port 수 = 1 우선
CDM type = noCDM 우선
BWP = full carrier bandwidth
NStartGrid = 0
NSizeGrid = 273
```

## MATLAB 후보 설정

```matlab
carrier = nrCarrierConfig;
carrier.NCellID = 1003;
carrier.SubcarrierSpacing = 30;
carrier.NStartGrid = 0;
carrier.NSizeGrid = 273;

% CSI-RS/TRS 설정은 MATLAB nrCSIRSConfig property 조합에 맞춰
% RowNumber, NumCSIRSPorts, CDMType, SubcarrierLocations 후보를 검증한다.
```

## 해석 기준

현재 설정은 `DU CSV에서 확정된 TRS/CSI-RS 시간/대역 후보 + 표준 TRS 가정`이다. 따라서 run2에서 생성되는 `recovery.csi.csirsCandidate`는 `confirmed CSI-RS extraction`이 아니라 `TRS/NZP CSI-RS hypothesis-based channel estimate`로 취급한다.

후보 추출 결과를 볼 때 확인할 값:

```text
Status: capture/profile dependent
Actual selected slot offset: check recovery.csi.csirsCandidate.assumptions.slotOffset
Actual selected subcarrier location: check recovery.csi.csirsCandidate.assumptions.subcarrierLocation
Valid sparse LS CSI samples: check recovery.csi.csirsCandidate.validRefReCount
Figure title also reports the current reference RE count.
```
