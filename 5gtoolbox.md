## 다운링크 물리 신호
동기화 신호
nrPSS	PSS 심볼 생성
nrPSSIndices	Generate PSS resource element indices
nrSSS	SSS 심볼 생성
nrSSSIndices	Generate SSS resource element indices
PDSCH 복조 기준 신호
nrPDSCHDMRS	PDSCH DM-RS 심볼 생성
nrPDSCHDMRSConfig	PDSCH DM-RS configuration parameters
nrPDSCHDMRSIndices	Generate PDSCH DM-RS indices
PBCH 복조 기준 신호
nrPBCHDMRS	PBCH DM-RS 심볼 생성
nrPBCHDMRSIndices	Generate PBCH DM-RS resource element indices
채널 상태 정보 기준 신호
nrCSIReportConfig	CSI reporting configuration parameters (R2025a 이후)
nrCSIRS	Generate CSI-RS symbols
nrCSIRSConfig	CSI-RS configuration parameters
nrCSIRSIndices	Generate CSI-RS resource element indices
PDSCH 위상 추적 기준 신호
nrPDSCHPTRS	Generate PDSCH PT-RS symbols
nrPDSCHPTRSConfig	PDSCH PT-RS configuration parameters
nrPDSCHPTRSIndices	Generate PDSCH PT-RS Indices
위치 지정 기준 신호
nrPRS	Generate PRS symbols (R2021a 이후)
nrPRSConfig	PRS configuration parameters (R2021a 이후)
nrPRSIndices	Generate PRS resource element indices (R2021a 이후)
반송파 구성
nrCarrierConfig	반송파 구성 파라미터
nrResourceGrid	빈 반송파 슬롯 리소스 그리드 생성
다운링크 물리 채널
Physical Broadcast Channel
nrPBCH	PBCH 변조 심볼 생성
nrPBCHDecode	Decode PBCH modulation symbols
nrPBCHIndices	Generate PBCH resource element indices
nrPBCHPRBS	Generate PBCH scrambling sequence
Physical Downlink Shared Channel
nrPDSCH	Generate PDSCH modulation symbols
nrPDSCHConfig	PDSCH configuration parameters
nrPDSCHDecode	Decode PDSCH modulation symbols
nrPDSCHDMRS	PDSCH DM-RS 심볼 생성
nrPDSCHDMRSConfig	PDSCH DM-RS configuration parameters
nrPDSCHDMRSIndices	Generate PDSCH DM-RS indices
nrPDSCHIndices	Generate PDSCH resource element indices
nrPDSCHPRBS	Generate PDSCH scrambling sequence
nrPDSCHPrecode	Precoding for PDSCH PRG bundling (R2023b 이후)
nrPDSCHPTRS	Generate PDSCH PT-RS symbols
nrPDSCHPTRSConfig	PDSCH PT-RS configuration parameters
nrPDSCHPTRSIndices	Generate PDSCH PT-RS Indices
nrPDSCHReservedConfig	PDSCH reserved PRB configuration parameters
nrPRGInfo	Precoding resource block group information (R2023b 이후)
Physical Downlink Control Channel
nrCORESETConfig	Control resource set (CORESET) configuration parameters
nrPDCCH	Generate PDCCH modulation symbols
nrPDCCHConfig	PDCCH configuration parameters
nrPDCCHDecode	Decode PDCCH modulation symbols
nrPDCCHPRBS	Generate PDCCH scrambling sequence
nrPDCCHResources	Generate PDCCH and PDCCH DM-RS resources
nrPDCCHSpace	Generate PDCCH resources for all candidates and aggregation levels
nrSearchSpaceConfig	Search space set configuration parameters
반송파 구성
nrCarrierConfig	반송파 구성 파라미터
nrResourceGrid	빈 반송파 슬롯 리소스 그리드 생성
다운링크 전송 채널
nrBCH	Broadcast channel (BCH) encoding
nrBCHDecode	Broadcast channel (BCH) decoding
nrDLSCH	Apply DL-SCH encoder processing chain
nrDLSCHDecoder	Apply DL-SCH decoder processing chain
nrDLSCHInfo	Get downlink shared channel (DL-SCH) information
다운링크 제어 정보
nrDCIDecode	Decode downlink control information (DCI)
nrDCIEncode	Encode downlink control information (DCI)
다운링크 OFDM 변조
nrOFDMDemodulate	Demodulate OFDM waveform
nrOFDMInfo	OFDM 정보 얻기
nrOFDMModulate	OFDM 변조 파형 생성
nrResourceGrid	빈 반송파 슬롯 리소스 그리드 생성

## 신호 수신 및 복구 — 함수
nrChannelEstimate	실질적 채널 추정
nrEqualizeMMSE	MMSE(최소평균제곱오차) 이퀄라이제이션
nrExtractResources	Extract resource elements from resource array
nrPerfectChannelEstimate	Perfect channel estimation
nrPerfectTimingEstimate	Perfect timing estimation
nrTimingEstimate	Practical timing estimation

## 측정
nrCSIRSMeasurements	CSI-RS-based physical layer measurements (R2022b 이후)
nrEVM	Measure error vector magnitude (EVM) (R2025a 이후)
nrSSBMeasurements	SSB-based physical layer measurements (R2022b 이후)