# SDR Capture to CSI Pipeline

이 문서는 `5g_channel_sounding` 프로젝트에서 SDR로 실제 5G private network downlink 신호를 캡처한 뒤, MATLAB 5G Toolbox 공식 예제 기반 receiver로 MIB/SIB1을 복구하고, 마지막으로 DM-RS 및 TRS/NZP CSI-RS 후보 기반 CSI figure와 결과 MAT 파일을 만드는 전체 흐름을 설명한다.

핵심 결론부터 정리하면 다음과 같다.

- 이 프로젝트의 receiver 알고리즘 기준은 MathWorks 공식 예제 `NRSSBCaptureUsingSDRExample`와 `NRCellSearchMIBAndSIB1RecoveryExample`이다.
- `run1_capture_ssb_using_sdr.m`은 SDR에서 raw IQ waveform을 캡처하고 SSB를 검출한 뒤, 다음 단계에서 그대로 읽을 수 있는 MAT 파일을 저장한다.
- `run2_recover_mib_sib1_with_figures.m`와 `run2_recover_mib_sib1_from_data.m`는 저장된 MAT 파일을 읽고, 공식 예제 receiver 흐름으로 PSS/SSS/PBCH/MIB/CORESET0/PDCCH/PDSCH/SIB1을 복구한다.
- 기본 CSI는 PBCH DM-RS와 SIB1 PDSCH DM-RS를 이용한 sparse least-squares channel estimate이다. 현재 run2는 추가로 TRS/NZP CSI-RS 후보 config에 대한 sparse LS CSI도 계산한다.
- CSI 계산식은 reference signal 위치마다 `H = Y / X`이다. DM-RS는 `H_DMRS = Y_DMRS / X_DMRS`, CSI-RS 후보는 `H_CSIRS = Y_CSIRS / X_CSIRS`로 계산한다.
- figure 저장을 켜면 공식 예제 figure와 프로젝트에서 추가한 CSI figure가 `outputs/2_processed/figures/<capture-file-name>/figures.pdf` 하나의 multipage PDF로 저장된다.

## 1. 측정 대상과 전제값

현재 프로젝트는 학교 5G 특화망의 downlink를 passive receive 방식으로 관측한다. UE attach, uplink transmit, NAS/RRC procedure 구현, user-data 복호화는 하지 않는다.

상세 환경값의 기준 문서는 `docs/resource.md`의 Known Environment이다. 여기서는 receiver 흐름 이해에 필요한 값만 요약한다.

```text
Network: 5G Private Network
Deployment: Rel-16 based
Band: n79
Channel bandwidth: 100 MHz
UE-observed / SSB ARFCN: 717216
UE-observed / SSB frequency: 4758.24 MHz
CSV cell-physical nr-arfcn-dl/ul: 718000
CSV cell-physical frequency equivalent: 4770.00 MHz
CSV ssb-loc-arfcn: 717216
SSB / GSCN capture frequency used by run1: 4758.24 MHz
GSCN used by run1: 8720
Confirmed PCI / NCellID: 1003
Confirmed SSB index: 1
Confirmed common SCS: 30 kHz
Confirmed k_SSB: 20
```

프로젝트 기본 SDR 설정은 `config/default_config.m`에 있다.

```matlab
cfg.ssbCapture.deviceName = "B210";
cfg.radio.serialNum = '3275420';
cfg.radio.gain = 35;
cfg.radio.channelMapping = 1;
cfg.ssbCapture.band = "n79";
cfg.ssbCapture.gscn = 8720;
cfg.ssbCapture.sampleRate = 61.44e6;
cfg.ssbCapture.framesPerCapture = 5;
cfg.receiver.minChannelBW = 40;
cfg.figures.format = "pdf";
```

`minChannelBW = 40`은 실제 배치가 100 MHz라는 뜻이 아니라, CORESET0 table/resource 계산에 사용할 FR1 최소 channel bandwidth selector이다. 실제 특화망은 100 MHz 배치로 알고 있지만, B210 capture bandwidth와 현재 sample rate로는 전체 100 MHz를 한 번에 관측하는 구조가 아니다. 따라서 현재 CSI는 full-band 100 MHz CSI가 아니라, 캡처된 bandwidth 안에서 복구 가능한 reference signal 기반 partial-band CSI로 해석해야 한다.

## 2. 실행 파일 역할

프로젝트에서 사용자가 직접 실행하는 핵심 파일은 세 개다.

```text
run1_capture_ssb_using_sdr.m
run2_recover_mib_sib1_with_figures.m
run2_recover_mib_sib1_from_data.m
```

`run1_capture_ssb_using_sdr.m`은 실제 SDR capture 단계다. USRP B210으로 GSCN 8720 중심의 downlink IQ waveform을 수신하고, SSB가 잡혔는지 확인한 뒤 MAT 파일로 저장한다.

```matlab
run1_capture_ssb_using_sdr
```

`run2_recover_mib_sib1_with_figures.m`는 tutorial처럼 figure를 보면서 한 캡처 파일을 분석하는 entry point다. 파일 상단의 `configuredCaptureFile`에서 분석할 MAT 파일을 지정할 수 있다.

```matlab
run2_recover_mib_sib1_with_figures
```

`run2_recover_mib_sib1_from_data.m`는 저장된 캡처 파일을 batch로 분석하고 결과를 저장하는 entry point다. 파일 상단의 `configuredDataFiles`에서 분석할 MAT 파일 또는 파일 목록을 지정할 수 있다.

```matlab
run2_recover_mib_sib1_from_data
```

figure 저장을 켜고 싶으면 다음처럼 실행한다.

```matlab
run2_recover_mib_sib1_with_figures("SaveFigures",true)
run2_recover_mib_sib1_from_data("SaveFigures",true)
```

현재 기본 figure format은 PDF다. 저장 결과는 캡처 파일 이름별 폴더 아래 하나의 multipage PDF로 만들어진다.

```text
outputs/2_processed/figures/<capture-file-name>/figures.pdf
```

## 3. Run 1: SDR에서 raw IQ waveform 캡처

`run1_capture_ssb_using_sdr.m`는 MathWorks `NRSSBCaptureUsingSDRExample`의 실제 SDR 수신 흐름을 프로젝트용 script로 정리한 것이다.

### 3.1 SDR 설정

먼저 프로젝트 root, `config/`, `src/`를 MATLAB path에 추가하고 `default_config`를 읽는다. 그 다음 `hSDRReceiver`를 생성해서 USRP B210을 설정한다.

```matlab
rx = hSDRReceiver(cfg.ssbCapture.deviceName);
rx.DeviceAddress = cfg.radio.serialNum;
rx.ChannelMapping = cfg.radio.channelMapping;
rx.Gain = cfg.radio.gain;
rx.OutputDataType = cfg.radio.outputDataType;
```

현재 기본값은 다음 의미다.

```text
Device: B210
Serial: 3275420
Channel mapping: 1
RX gain: 35 dB
Output type: single
```

`ChannelMapping = 1`은 B210의 receive channel 중 첫 번째 RF channel을 쓰겠다는 뜻이다. 안테나가 실제로 연결된 포트와 맞아야 하며, MIMO를 하겠다는 설정은 아니다.

### 3.2 GSCN에서 center frequency 결정

capture frequency는 직접 MHz 값을 hard-code하지 않고 GSCN에서 계산한다.

```matlab
rx.CenterFrequency = hSynchronizationRasterInfo.gscn2frequency(cfg.ssbCapture.gscn);
```

현재 `gscn = 8720`이므로 center frequency는 약 `4758.24 MHz`다. 이 값은 n79 특화망 후보값과 일치한다.

주의할 점은 `5g_NW_config` 안에 ARFCN 관련 값이 두 개 있다는 것이다. UE 관리페이지와 `ssb_config.csv`의 `ssb-loc-arfcn`은 `717216`, 즉 4758.24 MHz로 일치한다. 반면 `cell-physical-conf-idle.csv`에는 `nr-arfcn-dl/ul = 718000`도 따로 있다. 현재 run1은 UE에서 본 값과 같은 SSB/GSCN 주파수인 4758.24 MHz에 맞춰 캡처한다.

### 3.3 SSB SCS와 sample rate

SSB subcarrier spacing은 center frequency와 band 정보로부터 `hSynchronizationRasterInfo.getSCSOptions`를 통해 얻는다. 현재 n79/FR1에서는 SSB SCS가 `30 kHz`로 잡힌다.

SSB 자체는 20 RB, 즉 `240 subcarriers`만 쓰므로 SSB 검출만 보면 낮은 sample rate도 가능하다. 하지만 이후 SIB1 복구에는 CORESET0와 PDSCH까지 포함해야 하므로 `15.36 MS/s`는 부족할 수 있다. 실제로 현재 데이터에서는 `15.36 MS/s`로 MIB까지는 가능했지만 CORESET0 frequency resource가 waveform bandwidth 밖으로 나가 SIB1 recovery가 중단되었다.

현재 기본 sample rate는 다음과 같다.

```matlab
cfg.ssbCapture.sampleRate = 61.44e6;
```

검증된 결과 기준으로 `30.72 MS/s`와 `61.44 MS/s`에서는 SIB1 recovery가 성공했고, `15.36 MS/s`는 CORESET0를 포함하기에 부족했다.

### 3.4 capture duration

공식 예제 스타일을 따라 capture duration은 `framesPerCapture`로 결정된다.

```matlab
captureDuration = seconds((framesPerCapture+1)*10e-3);
```

현재 기본값은 `framesPerCapture = 5`이므로 총 capture duration은 `60 ms`다.

여기서 `+1` frame을 더 잡는 이유는 SSB burst timing, frame alignment, SIB1 monitoring occasion이 capture 앞뒤 경계에 걸릴 수 있기 때문이다. 즉 SSB 하나만 보는 것이 아니라, 이후 frame/slot 단위 복구까지 고려해서 약간 더 길게 잡는 구조다.

### 3.5 waveform 저장

SDR capture는 다음 변수로 저장된다.

```matlab
[waveform,captureTimestamp] = capture(rx,captureDuration);
```

저장 파일 이름은 다음 형식이다.

```text
outputs/1_IQcapture/capturedWaveform_<timestamp>.mat
```

저장되는 주요 변수는 다음과 같다.

```matlab
waveform              % complex baseband IQ samples
sampleRate            % capture sample rate
fPhaseComp            % carrier center frequency for OFDM symbol phase compensation
minChannelBW          % CORESET0 table selector
ssbBlockPattern       % SSB block pattern, for example Case C
L_max                 % maximum number of SS/PBCH blocks in burst
metadata              % device, gain, channel mapping, band, GSCN, timestamp
ssbInfo               % run1에서 검출한 SSB 관련 정보
captureTimestamp
```

중요한 점은 raw IQ가 `waveform`으로 그대로 저장된다는 것이다. 이후 `run2`는 SDR에 다시 접속하지 않고 이 `waveform`을 읽어서 offline receiver를 수행한다.

## 4. Run 1 내부 SSB 검출

`run1`은 저장 전에 SSB가 실제로 보이는지 빠르게 검증한다. 이 과정은 tutorial의 SSB capture 그림과 대응된다.

### 4.1 PSS 기반 coarse frequency correction

먼저 `hSSBurstFrequencyCorrect`가 waveform을 여러 candidate frequency offset으로 shift하면서 세 개의 PSS 후보 `NID2 = 0, 1, 2`와 correlation을 계산한다.

```matlab
[correctedWaveform,freqOffset,NID2] = hSSBurstFrequencyCorrect(...)
```

여기서 얻는 것은 다음이다.

```text
freqOffset: coarse/fine frequency offset estimate
NID2: strongest PSS sequence index
correctedWaveform: frequency offset이 보정된 waveform
```

PSS correlation plot에서 강한 peak가 하나 보이면 특정 frequency offset과 `NID2`가 뚜렷하게 검출된 것이다.

### 4.2 timing estimate와 OFDM demodulation

검출된 PSS를 reference grid에 넣고 `nrTimingEstimate`로 SSB timing offset을 구한다.

```matlab
timingOffset = nrTimingEstimate(correctedWaveform,nrbSSB,scsNumeric,nSlot,refGrid,"SampleRate",sampleRate);
```

그 다음 `nrOFDMDemodulate`로 SSB 주변 grid를 만든다.

```matlab
rxGrid = nrOFDMDemodulate(correctedWaveform,nrbSSB,scsNumeric,nSlot,"SampleRate",sampleRate);
rxGrid = rxGrid(:,2:5,:);
```

여기서 `rxGrid`는 SSB 4 symbols에 해당하는 `240 x 4` resource grid다.

### 4.3 SSS로 NCellID 결정

SSS는 `NID1`을 결정한다. PSS에서 얻은 `NID2`와 SSS에서 얻은 `NID1`을 합쳐 physical cell ID를 만든다.

```matlab
ncellid = (3*NID1) + NID2;
```

현재 성공한 캡처에서는 `ncellid = 1003`으로 확인되었다.

### 4.4 PBCH DM-RS hypothesis로 SSB index 후보 결정

PBCH DM-RS는 `ibar_SSB` 후보 `0:7`에 대해 각각 reference DM-RS를 생성하고, channel/noise estimate 기반 SNR이 가장 큰 후보를 선택한다.

```matlab
dmrsIndices = nrPBCHDMRSIndices(ncellid);
refGrid(dmrsIndices) = nrPBCHDMRS(ncellid,ibar_SSB);
[hest,nest] = nrChannelEstimate(rxGrid,refGrid,"AveragingWindow",[0 1]);
```

가장 큰 `dmrsEst`를 갖는 `ibar_SSB`가 선택되고, FR1에서 `L_max = 8`인 경우 `ssbIndex = ibar_SSB`로 이어진다. 현재 성공한 캡처에서는 `SSB index = 1`이 확인되었다.

### 4.5 PBCH/BCH CRC로 SSB 검출 확정

마지막으로 PBCH를 equalize/decode하고 BCH CRC를 확인한다. BCH CRC가 0이면 MIB를 decode할 수 있는 valid SSB로 본다.

`run1`에서 BCH CRC가 0이면 SSB resource grid figure를 띄우고, 붉은 박스로 strongest SSB 위치를 표시한다.

## 5. Run 2: 공식 예제 기반 MIB/SIB1 recovery

`run2` 분석의 핵심 구현은 `src/recoverMibSib1FromCapture.m`와 `src/NRCellSearchMIBAndSIB1RecoveryExample.m`에 있다.

`recoverMibSib1FromCapture`는 wrapper이고, 실제 receiver 알고리즘은 프로젝트에 복사된 공식 예제 script인 `NRCellSearchMIBAndSIB1RecoveryExample.m`이다.

wrapper는 다음 일을 한다.

- `captureFile` 경로를 resolve한다.
- `enablePlots`, `saveFigures`, `minChannelBW`, `figureFormat` 같은 실행 옵션을 준비한다.
- `evalc('run(scriptPath);')`로 공식 예제 script를 실행하고 console log를 캡처한다.
- 공식 예제 script가 workspace에 남긴 변수들을 `recovery` struct로 모은다.
- PBCH DM-RS와 PDSCH DM-RS에서 sparse LS CSI를 추가 계산한다.
- 결과 MAT 파일과 figure PDF를 저장한다.

중요한 구조는 다음과 같다.

```matlab
logText = evalc('run(scriptPath);');
```

이 말은 `run2`가 별도의 새 receiver를 임의로 구현하는 것이 아니라, 공식 예제 script를 실행해서 그 결과 변수들을 수집한다는 뜻이다.

## 6. Run 2 receiver 처리 순서

`NRCellSearchMIBAndSIB1RecoveryExample.m`의 처리 순서는 아래와 같다.

### 6.1 캡처 파일 로드

공식 예제 script는 `captureFile`에서 다음 변수를 읽는다.

```matlab
rx = load(captureFile,"waveform","sampleRate","fPhaseComp","minChannelBW","ssbBlockPattern","L_max");
rxWaveform = rx.waveform;
sampleRate = rx.sampleRate;
fPhaseComp = rx.fPhaseComp;
refBurst.BlockPattern = rx.ssbBlockPattern;
refBurst.L_max = rx.L_max;
```

즉 `run2`는 SDR hardware 상태와 무관하게 저장된 IQ waveform만으로 동작한다.

### 6.2 spectrogram

`enablePlots = true`이면 가장 먼저 received waveform spectrogram을 그린다.

```matlab
spectrogram(rxWaveform(:,1),ones(nfft,1),0,nfft,'centered',sampleRate,'yaxis','MinThreshold',-130);
```

이 figure는 capture bandwidth 안에서 에너지가 어떻게 분포하는지 보는 용도다.

### 6.3 PSS search와 frequency offset correction

PSS search는 coarse frequency offset과 `NID2`를 찾는다.

```matlab
searchBW = 6*scsSSB;
[rxWave,freqOffset,NID2] = hSSBurstFrequencyCorrect(rxWaveform,refBurst.BlockPattern,sampleRate,searchBW);
```

현재 `scsSSB = 30 kHz`이므로 search bandwidth는 `180 kHz`다. 후보 frequency offset을 바꿔가며 세 PSS sequence와 correlation을 계산하고, 가장 강한 peak를 선택한다.

실제 성공 로그 예시는 다음 형태다.

```text
-- Frequency correction and timing estimation --
Frequency offset: about -8 kHz
Cell identity: 1003
```

### 6.4 timing estimate와 SSB grid 추출

PSS가 들어간 reference grid로 timing offset을 잡고, OFDM demodulation을 수행한다.

```matlab
timingOffset = nrTimingEstimate(rxWave,nrbSSB,scsSSB,nSlot,refGrid,'SampleRate',sampleRate);
rxGrid = nrOFDMDemodulate(rxWave(1+timingOffset:end,:),nrbSSB,scsSSB,nSlot,'SampleRate',sampleRate);
rxGrid = rxGrid(:,2:5,:);
ssbGrid = rxGrid;
```

`ssbGrid`는 나중에 PBCH DM-RS CSI를 계산할 때 사용하기 위해 wrapper가 활용한다. 크기는 일반적으로 `240 x 4 x Nr`이다. 현재 single receive channel이면 effectively `240 x 4`로 해석할 수 있다.

### 6.5 SSS search와 cell ID

SSS RE를 뽑고 가능한 `NID1 = 0:335`에 대해 locally generated SSS와 correlation을 계산한다.

```matlab
sssIndices = nrSSSIndices;
sssRx = nrExtractResources(sssIndices,rxGrid);
ncellid = (3*NID1) + NID2;
```

성공 캡처에서는 `NCellID = 1003`이다.

### 6.6 PBCH DM-RS search

PBCH DM-RS는 SSB index 관련 hypothesis를 고르는 데 사용된다.

```matlab
dmrsIndices = nrPBCHDMRSIndices(ncellid);
for ibar_SSB = 0:7
    refGrid = zeros([240 4]);
    refGrid(dmrsIndices) = nrPBCHDMRS(ncellid,ibar_SSB);
    [hest,nest] = nrChannelEstimate(rxGrid,refGrid,'AveragingWindow',[0 1]);
    dmrsEst(ibar_SSB+1) = 10*log10(mean(abs(hest(:).^2)) / nest);
end
ibar_SSB = find(dmrsEst==max(dmrsEst)) - 1;
```

이 단계의 figure는 `PBCH DM-RS SNR Estimates`이며, 어떤 `ibar_SSB` hypothesis가 가장 강한지 보여준다.

### 6.7 PBCH channel estimation, equalization, BCH/MIB decoding

공식 예제는 PBCH DM-RS와 SSS를 reference grid에 넣고 SS/PBCH block 전체 channel estimate를 만든다.

```matlab
refGrid = zeros([nrbSSB*12 4]);
refGrid(dmrsIndices) = nrPBCHDMRS(ncellid,ibar_SSB);
refGrid(sssIndices) = nrSSS(ncellid);
[hest,nVar,hestInfo] = nrChannelEstimate(rxGrid,refGrid,'AveragingWindow',[0 1]);
ssbChannelGrid = hest;
ssbNoiseVariance = nVar;
ssbChannelEstimateInfo = hestInfo;
```

그 다음 PBCH RE를 추출하고 MMSE equalization을 수행한다.

```matlab
[pbchIndices,pbchIndicesInfo] = nrPBCHIndices(ncellid);
pbchRx = nrExtractResources(pbchIndices,rxGrid);
pbchHest = nrExtractResources(pbchIndices,hest);
[pbchEq,csi] = nrEqualizeMMSE(pbchRx,pbchHest,nVar);
```

여기서 공식 예제가 만든 `csi`는 PBCH soft bit weighting에 쓰이는 equalizer CSI다. 프로젝트는 이 값도 `recovery.csi.pbchEqualizerCSI`로 저장한다. 단, 이 값은 우리가 최종적으로 강조하는 sparse DM-RS LS CSI와는 목적이 다르다.

BCH decoding은 다음 흐름이다.

```matlab
pbchBits = nrPBCHDecode(pbchEq,ncellid,v,nVar);
pbchBits = pbchBits .* csi;
[~,crcBCH,trblk,sfn4lsb,nHalfFrame,msbidxoffset] = nrBCHDecode(...);
```

`crcBCH == 0`이면 MIB가 정상 복구된 것이다.

성공 캡처의 MIB 주요 출력은 다음과 같았다.

```text
SubcarrierSpacingCommon: 30
k_SSB: 20
DMRSTypeAPosition: 2
CellBarred: 1
IntraFreqReselection: 0
```

### 6.8 CORESET0 가능 여부와 sample rate 체크

MIB를 복구하면 SIB1을 찾기 위한 Type0-PDCCH CSS/CORESET0 정보를 알 수 있다.

공식 예제는 MIB의 `PDCCHConfigSIB1`, `k_SSB`, SCS 정보를 사용해 CORESET0 위치와 bandwidth를 계산한다.

```matlab
nrb = hCORESET0DemodulationBandwidth(initialSystemInfo,scsSSB,minChannelBW);
```

그 뒤 현재 capture sample rate가 CORESET0 resource를 포함할 만큼 충분한지 검사한다.

```matlab
if sampleRate < nrb*12*scsCommon*1e3
    requiredSampleRate = nrb*12*scsCommon*1e3;
    return;
end
```

현재 실험에서 `15.36 MS/s` 캡처는 이 단계에서 실패했다.

```text
Configured sample rate: 15.36 MS/s
Minimum sample rate for CORESET 0: 28.08 MS/s (78 RB @ 30 kHz SCS)
SIB1 recovery cannot continue. CORESET 0 resources are beyond the frequency limits...
```

따라서 SIB1 recovery와 PDSCH DM-RS CSI까지 얻으려면 최소 `30.72 MS/s` 이상이 필요했고, 현재 기본은 `61.44 MS/s`로 설정했다.

### 6.9 common SCS resource grid demodulation

SSB 복구는 SSB 중심의 `20 RB` grid에서 진행되지만, PDCCH/PDSCH는 common resource block raster에 맞춰야 한다. 그래서 MIB에서 얻은 `k_SSB`를 사용해 frequency shift를 적용한다.

```matlab
kFreqShift = k_SSB*scsKSSB*1e3;
rxWave = rxWave.*exp(1i*2*pi*kFreqShift*(0:length(rxWave)-1)'/sampleRate);
fPhaseComp = fPhaseComp - kFreqShift;
```

그 다음 CORESET0를 포함하는 bandwidth로 OFDM demodulation을 다시 수행한다.

```matlab
rxGrid = nrOFDMDemodulate(rxWave,nrb,scsCommon,nSlot, ...
    'SampleRate',sampleRate,'CarrierFrequency',fPhaseComp);
```

이 단계에서 그려지는 resource grid figure는 detected SSB와 CORESET0/PDCCH monitoring occasion의 위치 관계를 보여준다.

### 6.10 PDCCH blind decoding

SIB1은 PDSCH에 실려 있고, 그 PDSCH scheduling 정보는 PDCCH의 DCI format 1_0, SI-RNTI로 전달된다. 공식 예제는 MIB에서 얻은 `PDCCHConfigSIB1`을 바탕으로 CORESET0와 search space를 구성한다.

```matlab
[pdcch,csetPattern] = hPDCCH0Configuration(ssbIndex,initialSystemInfo,scsPair,ncellid,minChannelBW);
carrier = hCarrierConfigSIB1(ncellid,initialSystemInfo,pdcch);
dci = DCIFormat1_0_SIRNTI(pdcch.NSizeBWP);
siRNTI = 65535;
```

그 다음 monitoring slot마다 aggregation level과 candidate를 바꿔가며 blind decode한다.

```matlab
[pdcchInd,pdcchDmrsSym,pdcchDmrsInd] = nrPDCCHSpace(carrier,pdcch);
[hest,nVar,pdcchHestInfo] = nrChannelEstimate(rxSlotGrid,pdcchDmrsInd{aLevIdx}(:,cIdx),pdcchDmrsSym{aLevIdx}(:,cIdx));
dcicw = nrPDCCHDecode(pdcchEqSym,pdcch.DMRSScramblingID,pdcch.RNTI,nVar);
[dcibits,dciCRC] = nrDCIDecode(dcicw,dci.Width,polarListLength,siRNTI);
```

`dciCRC == 0`이면 SIB1 PDSCH scheduling DCI를 찾은 것이다.

성공 로그 예시는 다음과 같다.

```text
Decoded PDCCH candidate #1 at aggregation level 8
PDCCH CRC: 0
```

### 6.11 PDSCH configuration과 SIB1 decoding

DCI가 decode되면 DCI bits를 parsing해서 SIB1 PDSCH 설정을 얻는다.

```matlab
dci = fromBits(dci,dcibits);
[pdsch,K0] = hSIB1PDSCHConfiguration(dci,pdcch.NSizeBWP,initialSystemInfo.DMRSTypeAPosition,csetPattern);
```

이때 만들어지는 `pdsch` config가 이후 PDSCH DM-RS CSI 계산의 핵심 입력이다. 왜냐하면 PDSCH DM-RS의 위치와 symbol sequence는 PDSCH allocation, modulation, mapping type, DM-RS config에 따라 달라지기 때문이다.

공식 예제는 다음처럼 PDSCH DM-RS 위치와 송신 DM-RS symbol을 생성한다.

```matlab
pdschDmrsIndices = nrPDSCHDMRSIndices(carrier,pdsch);
pdschDmrsSymbols = nrPDSCHDMRS(carrier,pdsch);
```

그 다음 PDSCH channel estimate, equalization, DL-SCH decode를 수행한다.

```matlab
[hest,nVar,pdschHestInfo] = nrChannelEstimate(rxSlotGrid,pdschDmrsIndices,pdschDmrsSymbols);
pdschChannelGrid = hest;
pdschNoiseVariance = nVar;
[pdschIndices,pdschIndicesInfo] = nrPDSCHIndices(carrier,pdsch);
[pdschRxSym,pdschHest] = nrExtractResources(pdschIndices,rxSlotGrid,hest);
pdschEqSym = nrEqualizeMMSE(pdschRxSym,pdschHest,nVar);
cw = nrPDSCHDecode(carrier,pdsch,pdschEqSym,nVar);
[sib1bits,sib1CRC] = decodeDLSCH(...);
```

`sib1CRC == 0`이면 SIB1 복구가 성공한 것이다.

성공 로그 예시는 다음과 같다.

```text
PDSCH CRC: 0
SIB1 decoding succeeded.
```

## 7. CSI를 정확히 어디서 어떻게 구하는가

교수님이 가장 관심 가질 부분은 이 절이다.

현재 프로젝트에서 말하는 CSI는 다음 두 종류다.

```matlab
recovery.csi.pbchDmrsLs
recovery.csi.pdschDmrsLs
```

둘 다 공통적으로 sparse LS estimate다.

```matlab
H_DMRS(k,l) = Y_DMRS(k,l) / X_DMRS(k,l)
```

의미는 다음과 같다.

```text
Y_DMRS(k,l): 수신 resource grid의 DM-RS 위치에서 관측된 complex symbol
X_DMRS(k,l): 동일 위치에 송신되었어야 하는 known DM-RS complex symbol
H_DMRS(k,l): 해당 reference RE에서의 complex channel coefficient
```

이 계산은 reference signal이 있는 RE에서만 가능하다. 따라서 결과는 full dense channel matrix가 아니라 sparse CSI다. reference signal이 없는 RE는 `NaN`으로 남기고, `referenceMask`로 유효한 RE 위치를 표시한다.

### 7.1 PBCH DM-RS 기반 CSI

PBCH DM-RS CSI는 SSB/MIB 복구 단계에서 얻는다. 공식 예제가 이미 찾은 `ssbGrid`, `dmrsIndices`, `ncellid`, `ibar_SSB`를 사용한다.

실제 구현은 `src/recoverMibSib1FromCapture.m`에 있다.

```matlab
if exist("ssbGrid","var") && exist("dmrsIndices","var") && exist("ncellid","var") && exist("ibar_SSB","var")
    pbchDmrsSymbols = nrPBCHDMRS(ncellid,ibar_SSB);
    pbchDmrsRx = nrExtractResources(dmrsIndices,ssbGrid);
    pbchDmrsLsEstimate = pbchDmrsRx ./ pbchDmrsSymbols;
    pbchDmrsSparseGrid = nan(size(ssbGrid),"like",ssbGrid);
    pbchDmrsSparseGrid(dmrsIndices) = pbchDmrsLsEstimate;
    pbchDmrsMask = false(size(ssbGrid));
    pbchDmrsMask(dmrsIndices) = true;
end
```

여기서 중요한 점은 다음과 같다.

- `ssbGrid`는 PSS timing/frequency correction 이후 OFDM demodulation으로 얻은 strongest SSB의 `240 x 4` grid다.
- `dmrsIndices = nrPBCHDMRSIndices(ncellid)`는 PBCH DM-RS가 위치한 RE index다.
- `pbchDmrsSymbols = nrPBCHDMRS(ncellid,ibar_SSB)`는 해당 cell ID와 SSB hypothesis에서 송신되었어야 하는 known DM-RS sequence다.
- `pbchDmrsRx = nrExtractResources(dmrsIndices,ssbGrid)`는 수신 grid에서 DM-RS 위치만 뽑은 complex 관측값이다.
- `pbchDmrsLsEstimate = pbchDmrsRx ./ pbchDmrsSymbols`가 최종 PBCH DM-RS LS CSI다.

저장되는 주요 field는 다음과 같다.

```matlab
recovery.csi.pbchDmrsLs.source
recovery.csi.pbchDmrsLs.description
recovery.csi.pbchDmrsLs.NCellID
recovery.csi.pbchDmrsLs.ibarSSB
recovery.csi.pbchDmrsLs.ssbIndex
recovery.csi.pbchDmrsLs.indices
recovery.csi.pbchDmrsLs.rxSymbols
recovery.csi.pbchDmrsLs.txSymbols
recovery.csi.pbchDmrsLs.lsEstimate
recovery.csi.pbchDmrsLs.sparseGrid
recovery.csi.pbchDmrsLs.referenceMask
recovery.csi.pbchDmrsLs.ssbGridSize
recovery.csi.pbchDmrsLs.validRefReCount
recovery.csi.pbchDmrsLs.meanAbsEstimate
recovery.csi.pbchDmrsLs.maxAbsEstimate
recovery.csi.pbchDmrsLs.officialChannelGrid
recovery.csi.pbchDmrsLs.noiseVariance
recovery.csi.pbchDmrsLs.channelEstimateInfo
```

현재 성공 캡처에서 PBCH DM-RS reference RE 수는 다음과 같이 확인되었다.

```text
PBCH DM-RS CSI refs: 144
```

PBCH DM-RS CSI의 장점은 SSB/MIB만 성공하면 얻을 수 있다는 것이다. 즉 PDCCH/DCI/SIB1까지 성공하지 않아도 기본적인 cell-specific channel observation을 얻을 수 있다. 단점은 SSB block의 좁은 240 subcarrier, 4 symbol 구간에 한정된다는 것이다.

### 7.2 SIB1 PDSCH DM-RS 기반 CSI

PDSCH DM-RS CSI는 SIB1 recovery가 성공할 때 얻는다. DCI decoding을 통해 SIB1 PDSCH allocation을 알아야 하므로 PBCH DM-RS보다 조건이 더 까다롭다.

공식 예제가 만든 변수는 다음이다.

```matlab
carrier
pdsch
rxSlotGrid
pdschDmrsIndices
pdschDmrsSymbols
```

프로젝트 wrapper는 이 변수들을 이용해 sparse LS CSI를 계산한다.

```matlab
if exist("rxSlotGrid","var") && exist("pdschDmrsIndices","var") && exist("pdschDmrsSymbols","var")
    pdschDmrsRx = nrExtractResources(pdschDmrsIndices,rxSlotGrid);
    pdschDmrsLsEstimate = pdschDmrsRx ./ pdschDmrsSymbols;
    pdschDmrsSparseGrid = nan(size(rxSlotGrid),"like",rxSlotGrid);
    pdschDmrsSparseGrid(pdschDmrsIndices) = pdschDmrsLsEstimate;
    pdschDmrsMask = false(size(rxSlotGrid));
    pdschDmrsMask(pdschDmrsIndices) = true;
end
```

여기서 중요한 점은 다음과 같다.

- `rxSlotGrid`는 CORESET0/PDSCH가 있는 monitoring slot을 common SCS 기준으로 OFDM demodulation한 resource grid다.
- `pdschDmrsIndices = nrPDSCHDMRSIndices(carrier,pdsch)`는 decoded DCI와 MIB information으로 구성된 SIB1 PDSCH DM-RS 위치다.
- `pdschDmrsSymbols = nrPDSCHDMRS(carrier,pdsch)`는 그 위치에 송신되었어야 하는 known DM-RS sequence다.
- `pdschDmrsRx = nrExtractResources(pdschDmrsIndices,rxSlotGrid)`는 수신 grid에서 PDSCH DM-RS 위치만 뽑은 값이다.
- `pdschDmrsLsEstimate = pdschDmrsRx ./ pdschDmrsSymbols`가 최종 SIB1 PDSCH DM-RS LS CSI다.

저장되는 주요 field는 다음과 같다.

```matlab
recovery.csi.pdschDmrsLs.source
recovery.csi.pdschDmrsLs.description
recovery.csi.pdschDmrsLs.NCellID
recovery.csi.pdschDmrsLs.indices
recovery.csi.pdschDmrsLs.rxSymbols
recovery.csi.pdschDmrsLs.txSymbols
recovery.csi.pdschDmrsLs.lsEstimate
recovery.csi.pdschDmrsLs.sparseGrid
recovery.csi.pdschDmrsLs.referenceMask
recovery.csi.pdschDmrsLs.slotGridSize
recovery.csi.pdschDmrsLs.validRefReCount
recovery.csi.pdschDmrsLs.meanAbsEstimate
recovery.csi.pdschDmrsLs.maxAbsEstimate
recovery.csi.pdschDmrsLs.officialChannelGrid
recovery.csi.pdschDmrsLs.noiseVariance
recovery.csi.pdschDmrsLs.channelEstimateInfo
recovery.csi.pdschDmrsLs.carrier
recovery.csi.pdschDmrsLs.pdsch
```

현재 성공 캡처에서 PDSCH DM-RS reference RE 수는 다음과 같이 확인되었다.

```text
PDSCH DM-RS CSI refs: 612
```

PDSCH DM-RS CSI의 장점은 SSB보다 넓은 PDSCH allocation 영역에서 channel을 관측할 수 있다는 것이다. 단점은 DCI/PDSCH/SIB1 decode가 성공해야만 얻을 수 있고, SIB1이 실제로 할당된 PRB/symbol 범위에만 한정된다는 것이다.

### 7.3 `nrChannelEstimate` 결과와 LS CSI의 차이

공식 예제는 equalization을 위해 `nrChannelEstimate`를 사용한다.

```matlab
[hest,nVar,hestInfo] = nrChannelEstimate(...)
```

이 `hest`는 DM-RS나 SSS reference를 기반으로 grid 내 channel을 추정한 결과이며, averaging/interpolation이 들어간 receiver용 channel estimate다. 프로젝트는 이 값도 보존한다.

```matlab
recovery.csi.pbchDmrsLs.officialChannelGrid
recovery.csi.pdschDmrsLs.officialChannelGrid
```

하지만 교수님께 설명할 때 “우리가 CSI로 직접 산출한 값”은 다음 LS estimate라고 보면 된다.

```matlab
lsEstimate = rxSymbols ./ txSymbols;
```

즉, 복잡한 interpolation 결과만 저장한 것이 아니라 reference RE에서 관측된 raw complex channel coefficient를 직접 저장한다. 이 값은 나중에 magnitude, phase, 시간 반복 측정 비교, reference RE별 통계 계산에 쓰기 좋다.

### 7.4 이 CSI가 아닌 것

현재 결과를 해석할 때 아래를 명확히 구분해야 한다.

- 현재 `csirsCandidate`는 confirmed CSI-RS가 아니라 TRS/NZP CSI-RS 후보 기반 CSI다.
- 현재 CSI는 full-band 100 MHz channel estimate가 아니다.
- 현재 CSI는 CIR/PDP가 아니다.
- 현재 CSI는 UE feedback CSI, PMI/RI/CQI 같은 report가 아니다.
- 현재 DM-RS CSI는 gNB가 송신한 known DM-RS를 passive receiver가 관측해서 만든 complex channel coefficient다.
- 현재 CSI-RS 후보 CSI는 `docs/trs_nzp_csirs_candidate.md`의 가정값으로 만든 `nrCSIRSConfig`를 사용해 같은 방식으로 계산한 complex channel coefficient다.

Confirmed CSI-RS 기반 CSI를 주장하려면 gNB의 정확한 CSI-RS resource configuration이 필요하다. 현재 `csirsCandidate`는 DU CSV에서 찾은 period/symbol 후보와 표준 TRS 가정을 적용한 hypothesis-based result이다.

## 8. CSI figure는 무엇을 보여주는가

CSI figure는 `src/plotCsiFigures.m`에서 만든다.

```matlab
figureHandles = plotCsiFigures(recovery.csi);
```

PBCH DM-RS CSI가 있으면 `PBCH DM-RS CSI` figure를 만들고, PDSCH DM-RS CSI가 있으면 `SIB1 PDSCH DM-RS CSI` figure를 만든다. CSI-RS 후보가 있으면 `TRS/NZP CSI-RS Candidate CSI` figure도 만든다.

각 CSI figure는 2x2 layout이다.

```text
1. |H_DMRS| sparse grid magnitude in dB
2. angle(H_DMRS) sparse grid phase in radians
3. magnitude over reference RE index
4. unwrapped phase over reference RE index
```

구현은 다음과 같다.

```matlab
magDbGrid = 20*log10(abs(sparseGrid) + eps);
phaseGrid = angle(sparseGrid);
magDbGrid(~referenceMask) = NaN;
phaseGrid(~referenceMask) = NaN;
```

`referenceMask`가 false인 RE는 DM-RS가 없는 위치이므로 figure에서 비워둔다. 따라서 CSI sparse grid figure에서 점 또는 줄무늬처럼 보이는 부분만 실제 reference signal 기반 estimate가 있는 위치다.

reference RE order plot은 `lsEstimate(:)` 순서대로 magnitude와 phase를 보여준다.

```matlab
plot(refIndex,20*log10(abs(lsEstimate) + eps),".-")
plot(refIndex,unwrap(angle(lsEstimate)),".-")
```

이 그림은 주파수/시간 grid 모양보다 reference symbol 순서에 따른 channel coefficient 변화를 보기 위한 것이다.

## 9. 공식 예제 figure와 저장 방식

`run2`에서 `enablePlots = true`이면 공식 예제 script가 여러 figure를 만든다.

대표적인 figure는 다음과 같다.

```text
Spectrogram of the Received Waveform
PSS Correlations versus Frequency Offset
SSS Correlations (Frequency Domain)
PBCH DM-RS SNR Estimates
Equalized PBCH Constellation
Received Resource Grid with SSB / CORESET0
Equalized PDCCH Constellation
Slot Containing Decoded PDCCH and PDSCH
Equalized PDSCH Constellation
PBCH DM-RS CSI
SIB1 PDSCH DM-RS CSI
```

`recoverMibSib1FromCapture`는 실행 전후 figure handle 차이를 비교해서 이번 run에서 새로 만들어진 figure만 잡는다.

```matlab
figuresBeforeRun = findall(groot,"Type","figure");
logText = evalc('run(scriptPath);');
createdFigures = getCreatedFigures(figuresBeforeRun);
```

그 뒤 `SaveFigures = true`이고 `FigureFormat = "pdf"`이면 공식 예제 figure와 CSI figure를 합쳐 하나의 PDF로 저장한다.

```matlab
allFigureHandles = [createdFigures; csiFigureHandles];
recovery.figureFiles = saveFigureSet(allFigureHandles,figureDir,"figures",figureFormat);
```

`saveFigureSet`은 PDF일 때 `exportgraphics`의 append 기능을 사용한다.

```matlab
outputFile = fullfile(outputDir,filePrefix + ".pdf");
for figIdx = 1:numel(figures)
    exportgraphics(figures(figIdx),outputFile,"Append",figIdx > 1);
end
```

따라서 저장 결과는 다음 하나다.

```text
outputs/2_processed/figures/<capture-file-name>/figures.pdf
```

PNG 저장에서 PSS correlation 그림이 이상하게 보였던 문제가 있었기 때문에 현재 기본은 PDF다. MATLAB에서 열린 figure 자체는 정상이고, PDF 저장 결과도 정상적으로 보이는 것을 확인했다.

## 10. 결과 MAT 파일 구조

`run2`는 분석 결과를 다음 위치에 저장한다.

```text
outputs/2_processed/<capture-file-name>_mib_sib1_recovery.mat
```

이 파일 안에는 `recovery` struct가 들어 있다.

주요 field는 다음과 같다.

```matlab
recovery.captureFile
recovery.algorithm
recovery.status
recovery.success
recovery.error
recovery.logText
recovery.sampleRate
recovery.fPhaseComp
recovery.minChannelBW
recovery.sync
recovery.ssb
recovery.mib
recovery.pdcch
recovery.sib1
recovery.csi
recovery.outputPath
recovery.figureFiles
```

`recovery.status`는 대략 다음 값 중 하나가 된다.

```text
started
completed
sib1_succeeded
sib1_failed
insufficient_sample_rate_for_coreset0
dci_failed
bch_failed
coreset0_not_present
search_space_beyond_waveform
error
```

가장 좋은 정상 상태는 다음이다.

```text
recovery.status = "sib1_succeeded"
recovery.success = true
recovery.mib.bchCRC = 0
recovery.pdcch.dciCRC = 0
recovery.sib1.crc = 0
```

CSI를 MATLAB에서 확인하려면 다음처럼 한다.

```matlab
load("outputs/2_processed/61.44_260507_mib_sib1_recovery.mat")

pbchCsi = recovery.csi.pbchDmrsLs;
pdschCsi = recovery.csi.pdschDmrsLs;

size(pbchCsi.lsEstimate)
size(pdschCsi.lsEstimate)

pbchCsi.validRefReCount
pdschCsi.validRefReCount
```

## 11. batch summary

`run2_recover_mib_sib1_from_data.m`는 여러 MAT 파일을 반복 분석한 뒤 summary table을 저장한다.

```text
outputs/2_processed/mib_sib1_batch_<timestamp>.mat
```

summary table에는 다음 항목이 들어간다.

```text
captureFile
status
success
sampleRateMsps
frequencyOffsetHz
timingOffsetSamples
ncellid
ssbIndex
pbchEVMrmsPercent
bchCRC
pdcchEVMrmsPercent
dciCRC
pdschEVMrmsPercent
sib1CRC
pbchDmrsCsiRefs
pdschDmrsCsiRefs
figureFileCount
resultFile
```

현재 성공 캡처에서 확인된 대표 결과는 다음이다.

```text
Capture: 61.44_260507.mat
Sample rate: 61.44 MS/s
NCellID / PCI: 1003
SSB index: 1
BCH CRC: 0
DCI CRC: 0
SIB1 CRC: 0
Status: sib1_succeeded
PBCH DM-RS CSI refs: 144
PDSCH DM-RS CSI refs: 612
Figure output: outputs/2_processed/figures/61.44_260507/figures.pdf
```

## 12. 교수님께 설명할 때의 핵심 논리

이 프로젝트의 측정/분석 논리는 아래 순서로 설명하면 된다.

1. SDR은 n79 GSCN 8720, 약 4758.24 MHz의 SSB sync raster 중심에서 complex baseband IQ waveform을 수신한다. 이 값은 UE 관리페이지의 ARFCN 717216과 `ssb_config.csv`의 `ssb-loc-arfcn`에 대응한다.
2. MATLAB 5G Toolbox 공식 SSB capture 흐름으로 PSS/SSS/PBCH를 찾아 실제 cell이 잡혔는지 검증한다.
3. 캡처된 waveform과 receiver parameter를 MAT 파일로 저장한다.
4. 저장된 waveform을 공식 `NRCellSearchMIBAndSIB1RecoveryExample` receiver에 넣는다.
5. receiver는 PSS로 frequency offset과 `NID2`를 잡고, SSS로 `NID1`을 잡아 `NCellID = 1003`을 얻는다.
6. PBCH DM-RS hypothesis search로 `ibar_SSB`와 SSB index를 결정한다.
7. PBCH를 equalize/decode해서 BCH CRC 0을 확인하고 MIB를 얻는다.
8. MIB에서 common SCS, `k_SSB`, CORESET0/PDCCHConfigSIB1 정보를 얻는다.
9. CORESET0 resource가 capture bandwidth 안에 있는지 sample rate를 검사한다.
10. PDCCH monitoring occasion에서 SI-RNTI DCI format 1_0을 blind decode한다.
11. DCI에서 SIB1 PDSCH allocation을 얻고, PDSCH DM-RS를 이용해 PDSCH를 equalize/decode한다.
12. DL-SCH CRC가 0이면 SIB1 recovery 성공이다.
13. CSI는 이 과정에서 이미 정확히 위치와 sequence를 알게 된 PBCH DM-RS와 PDSCH DM-RS를 이용해 `H = Y / X`로 계산한다.
14. 저장된 CSI는 complex value이므로 magnitude뿐 아니라 phase도 보존된다.
15. figure PDF는 공식 예제 receiver figure와 CSI diagnostic figure를 같은 run에서 만든 결과다.

가장 중요한 표현은 다음이다.

```text
이 CSI는 blind하게 만든 임의의 채널 추정이 아니라, MIB/SIB1 recovery 과정에서 공식 예제가 복구한 cell ID, SSB index, DCI/PDSCH configuration을 이용해 known DM-RS 위치와 sequence를 재생성하고, 같은 위치의 수신 symbol과 나누어서 얻은 sparse complex LS channel estimate다.
```

## 13. 해석 시 주의점

현재 결과를 논문/보고서/미팅 자료로 설명할 때는 다음 제한을 같이 말해야 한다.

- B210과 현재 sample rate 설정은 100 MHz 전체 대역을 full-band로 capture하는 구성이 아니다.
- PBCH DM-RS CSI는 SSB 영역의 narrowband CSI다.
- PDSCH DM-RS CSI는 SIB1 PDSCH allocation 영역의 CSI다.
- 두 CSI 모두 reference signal이 존재하는 RE에서만 직접 계산된다.
- grid 전체 channel이 필요하면 `nrChannelEstimate`의 interpolated `officialChannelGrid`를 참고할 수 있지만, 그것은 interpolation/averaging이 포함된 receiver estimate다.
- CSI-RS 기반 CSI를 주장하려면 gNB CSI-RS configuration이 추가로 필요하다.
- 현재 프로젝트 scope는 CIR/PDP가 아니라 complex frequency-domain CSI다.

## 14. 재현 명령어

MATLAB에서 프로젝트 폴더로 이동한다.

```matlab
cd('/home/jinsub/channel/5g_channel_sounding')
```

SDR에서 새 캡처를 수행한다.

```matlab
run1_capture_ssb_using_sdr
```

저장된 캡처 하나를 figure와 함께 분석한다.

```matlab
run2_recover_mib_sib1_with_figures
```

figure PDF까지 저장한다.

```matlab
run2_recover_mib_sib1_with_figures("SaveFigures",true)
```

batch 분석과 결과 저장을 수행한다.

```matlab
run2_recover_mib_sib1_from_data
```

batch 분석에서 figure PDF까지 저장한다.

```matlab
run2_recover_mib_sib1_from_data("SaveFigures",true)
```

분석할 파일을 고정하려면 각 run2 파일 상단의 user settings를 바꾼다.

```matlab
% run2_recover_mib_sib1_with_figures.m
configuredCaptureFile = "outputs/1_IQcapture/61.44_260507.mat";

% run2_recover_mib_sib1_from_data.m
configuredDataFiles = "outputs/1_IQcapture/61.44_260507.mat";
```

## 15. 관련 코드 위치

전체 흐름을 코드에서 확인하려면 다음 파일을 보면 된다.

```text
config/default_config.m
run1_capture_ssb_using_sdr.m
run2_recover_mib_sib1_with_figures.m
run2_recover_mib_sib1_from_data.m
src/NRCellSearchMIBAndSIB1RecoveryExample.m
src/recoverMibSib1FromCapture.m
src/extractCsirsCandidateCsi.m
src/plotCsiFigures.m
src/saveFigureSet.m
```

가장 중요한 DM-RS CSI 계산부는 `src/recoverMibSib1FromCapture.m` 안의 아래 두 block이다.

```text
PBCH DM-RS LS CSI block:
if exist("ssbGrid","var") && exist("dmrsIndices","var") ...

SIB1 PDSCH DM-RS LS CSI block:
if exist("rxSlotGrid","var") && exist("pdschDmrsIndices","var") ...
```

CSI-RS 후보 스캔/선택/추출은 `src/extractCsirsCandidateCsi.m`에 있다.

figure 생성부는 `src/plotCsiFigures.m`, multipage PDF 저장부는 `src/saveFigureSet.m`에 있다.

## 16. CSI-RS로 확장하려면 필요한 정보

현재 프로젝트는 PBCH DM-RS와 SIB1 PDSCH DM-RS로 CSI를 얻는다. CSI-RS를 추출하려면 추가 정보가 필요하다. 이유는 간단하다. DM-RS는 MIB/SIB1 recovery 과정에서 cell ID, SSB index, DCI, PDSCH allocation을 decode하면 위치와 sequence를 재생성할 수 있지만, CSI-RS는 보통 별도의 RRC configuration으로 설정되며 MIB/SIB1만으로는 resource 위치와 주기를 확정할 수 없기 때문이다.

CSI-RS 기반 CSI를 신뢰성 있게 주장하려면 최소한 다음 정보가 필요하다.

```text
1. CSI-RS type
   - NZP CSI-RS인지 ZP CSI-RS인지
   - channel estimation에 사용할 것은 일반적으로 NZP CSI-RS

2. CSI-RS resource mapping
   - row number / number of antenna ports
   - frequency-domain allocation
   - OFDM symbol location
   - density
   - CDM type
   - RB offset and number of RBs
   - scrambling identity

3. Time-domain occurrence
   - periodic / semi-persistent / aperiodic 여부
   - periodicity
   - slot offset
   - frame/slot 기준 timing

4. Carrier and BWP mapping
   - subcarrier spacing
   - NStartGrid, NSizeGrid
   - active BWP start and size
   - Point A 또는 CRB 기준 offset
   - CSI-RS가 capture bandwidth 안에 들어오는지 여부

5. Port/layer interpretation
   - CSI-RS port 개수
   - port별 resource mapping
   - 수신 안테나 개수
   - port별 channel coefficient를 어떻게 저장할지

6. gNB configuration source
   - gNB 설정 파일
   - DU/CU log
   - UE RRC log
   - 계측 UE log
   - 또는 운영자가 제공한 CSI-RS resource configuration
```

특히 중요한 것은 `CSI-RS resource mapping`과 `periodicity/slot offset`이다. 이 두 가지가 없으면 수신 grid의 어느 RE가 CSI-RS인지 알 수 없다. 임의로 energy가 보이는 RE를 CSI-RS라고 가정하면 다른 downlink signal, PDSCH, DM-RS, interference와 구분하기 어렵다.

### 16.1 MIB/SIB1만으로 부족한 이유

MIB는 initial access에 필요한 최소 정보만 제공한다. SIB1은 cell access와 initial BWP/PDCCH 관련 정보를 제공하지만, UE별 CSI measurement/reporting을 위한 CSI-RS resource configuration은 일반적으로 dedicated RRC signaling에서 내려온다.

현재 프로젝트가 decode하는 것은 SIB1까지다. 따라서 현재 정보로 확실히 알 수 있는 reference signal은 다음 정도다.

```text
SSB/PBCH DM-RS:
  Cell ID와 SSB hypothesis로 재생성 가능

SIB1 PDSCH DM-RS:
  SI-RNTI DCI를 decode한 뒤 PDSCH allocation으로 재생성 가능
```

반면 CSI-RS는 다음 정보가 없으면 재생성할 수 없다.

```text
CSI-RS가 어느 slot에 나오는가
CSI-RS가 어느 symbol/subcarrier/PRB에 매핑되는가
CSI-RS sequence scrambling ID가 무엇인가
CSI-RS port 수와 CDM 구조가 무엇인가
```

그래서 현재 단계에서 “CSI-RS를 blind로 추출했다”고 말하는 것은 위험하다. 가능은 하더라도 research hypothesis이고, 공식 예제 기반 검증된 pipeline이라고 말하기 어렵다.

### 16.2 현재 구현된 CSI-RS 후보 추출

현재 run2는 `docs/trs_nzp_csirs_candidate.md`의 CSV 확인값과 가정값을 사용해 TRS/NZP CSI-RS 후보 CSI를 계산한다. 목적은 RSRP/RSRQ 같은 측정값이 아니라 DM-RS CSI와 같은 복소 채널값이다.

구현 위치는 `src/extractCsirsCandidateCsi.m`이며, `src/recoverMibSib1FromCapture.m`의 run2 recovery 후반부에서 호출한다. 공식 CSI-RS 예제의 핵심 흐름만 이식했다.

```text
1. run2 receiver가 frame/slot timing과 common OFDM grid를 복구한다.
2. `nrCSIRSConfig`로 TRS/NZP CSI-RS 후보 resource를 구성한다.
3. `nrCSIRSIndices`로 후보 RE 위치를 계산한다.
4. `nrCSIRS`로 known CSI-RS reference symbol을 생성한다.
5. 수신 grid에서 같은 RE의 `Y_CSIRS`를 추출한다.
6. `H_CSIRS = Y_CSIRS ./ X_CSIRS`로 sparse LS CSI를 계산한다.
7. `nrChannelEstimate`도 같은 candidate RE로 실행해 noise/channel-estimate metadata를 남긴다.
8. 결과를 `recovery.csi.csirsCandidate`에 저장한다.
```

구조는 다음과 같은 형태가 된다.

```matlab
% Pseudocode. Exact object/property names should follow the MATLAB release.
csirs = nrCSIRSConfig;
csirs.CSIRSType = {"nzp","nzp"};
csirs.CSIRSPeriod = {[40 selectedSlotOffset],[40 selectedSlotOffset]};
csirs.RowNumber = [1 1];
csirs.Density = {"three","three"};
csirs.SymbolLocations = {6,10};
csirs.SubcarrierLocations = {selectedSubcarrierLocation,selectedSubcarrierLocation};
csirs.NID = ncellid;

csirsIndices = nrCSIRSIndices(carrier,csirs);
csirsSymbols = nrCSIRS(carrier,csirs);

csirsRx = nrExtractResources(csirsIndices,rxGrid);
csirsLsEstimate = csirsRx ./ csirsSymbols;
```

`selectedSlotOffset`과 `selectedSubcarrierLocation`은 CSV에서 확정되지 않았으므로 현재 구현에서 후보들을 점수화해 고른다. 따라서 이 결과는 confirmed CSI-RS가 아니라 candidate-based channel estimate다.

저장 구조는 기존 DM-RS CSI와 맞췄다.

```matlab
recovery.csi.csirsCandidate.source
recovery.csi.csirsCandidate.assumptions
recovery.csi.csirsCandidate.csirs
recovery.csi.csirsCandidate.rxSymbols
recovery.csi.csirsCandidate.txSymbols
recovery.csi.csirsCandidate.lsEstimate
recovery.csi.csirsCandidate.sparseGrid
recovery.csi.csirsCandidate.referenceMask
recovery.csi.csirsCandidate.validRefReCount
```

### 16.3 실제로 다음에 해야 할 일

CSI-RS를 목표로 한다면 다음 순서로 진행하는 것이 가장 현실적이다.

```text
1. 학교 특화망 gNB 설정에서 CSI-RS가 켜져 있는지 확인한다.
2. 켜져 있다면 NZP CSI-RS resource configuration을 요청한다.
3. configuration에 periodicity와 slot offset이 있으면 capture duration을 그 주기보다 충분히 길게 설정한다.
4. CSI-RS resource가 현재 sample rate/capture bandwidth 안에 들어오는지 계산한다.
5. 들어오지 않으면 B210으로는 해당 CSI-RS를 볼 수 없으므로 center frequency/sample rate/capture 장비 조건을 바꿔야 한다.
6. 들어오면 `run2`의 CSI-RS 후보 결과와 비교하고, 가정값을 confirmed config로 바꾼다.
7. DM-RS CSI와 CSI-RS CSI의 magnitude/phase를 비교해 같은 channel trend를 보이는지 검증한다.
```

만약 gNB 설정을 받을 수 없다면, `csirsCandidate`는 계속 hypothesis-based result로 취급해야 한다. 보고서에서는 confirmed CSI-RS extraction이라고 쓰지 말고, TRS/NZP CSI-RS candidate-based channel estimate라고 쓴다.

### 16.4 보고서에 쓸 수 있는 정리 문장

현재 단계의 정확한 표현은 다음이다.

```text
본 프로젝트에서는 MIB/SIB1 recovery 과정에서 위치와 sequence가 확정되는 PBCH DM-RS 및 SIB1 PDSCH DM-RS를 이용해 sparse LS CSI를 계산했다. 또한 DU CSV에서 확인한 TRS/NZP CSI-RS 후보 정보와 표준 TRS 가정을 기반으로 `nrCSIRSConfig`를 구성하고, 같은 `H = Y/X` 방식으로 CSI-RS 후보 RE의 complex channel coefficient를 추출했다. 단, exact CSI-RS resource mapping이 아직 확정되지 않았으므로 이 결과는 confirmed CSI-RS가 아니라 hypothesis-based candidate CSI로 해석한다.
```
