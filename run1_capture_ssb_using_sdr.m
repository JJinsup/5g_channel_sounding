function result = run1_capture_ssb_using_sdr(varargin)
%RUN1_CAPTURE_SSB_USING_SDR Capture and analyze an SSB using the MathWorks flow.
%   This is the project entry point corresponding to the MathWorks
%   NRSSBCaptureUsingSDRExample live script. It captures one OTA waveform,
%   plots the strongest SSB when BCH decoding succeeds, and saves a MAT file
%   compatible with NRCellSearchMIBAndSIB1RecoveryExample.
%
%   run1_capture_ssb_using_sdr("SaveFigures",true) saves generated figures
%   under outputs/2_processed/figures/<capture-file-name>.

repoRoot = fileparts(mfilename("fullpath"));
addpath(fullfile(repoRoot,"config"));
addpath(fullfile(repoRoot,"src"));

%% User Settings
configuredConfigFile = "config/x300_config.m";

[configFile,overrides,runOptions] = parseInputs(varargin{:});
if strlength(configFile) == 0
    configFile = configuredConfigFile;
end
cfg = load_project_config(repoRoot,configFile,overrides);

fprintf("=== SSB Capture Using SDR ===\n");
fprintf("Device: %s\n",cfg.ssbCapture.deviceName);
fprintf("Config: %s\n",configFile);
fprintf("Device series: %s\n",cfg.radio.deviceSeries);
fprintf("Band: %s\n",cfg.ssbCapture.band);
fprintf("GSCN: %d\n",cfg.ssbCapture.gscn);
fprintf("Gain: %.1f dB\n",cfg.radio.gain);
fprintf("Channel mapping: %s\n",mat2str(cfg.radio.channelMapping));
if isfield(cfg.radio,"transportDataType") && strlength(string(cfg.radio.transportDataType)) > 0
    fprintf("Transport data type: %s\n",string(cfg.radio.transportDataType));
end

rx = [];
cleanupObj = onCleanup(@() releaseReceiver(rx));

rx = hSDRReceiver(cfg.ssbCapture.deviceName);
if strlength(string(cfg.radio.serialNum)) > 0
    rx.DeviceAddress = cfg.radio.serialNum;
end
if isfield(cfg.radio,"transportDataType") && strlength(string(cfg.radio.transportDataType)) > 0
    rx.TransportDataType = cfg.radio.transportDataType;
end
rx.ChannelMapping = cfg.radio.channelMapping;
rx.Gain = cfg.radio.gain;
rx.OutputDataType = cfg.radio.outputDataType;

syncRasterInfo = hSynchronizationRasterInfo.SynchronizationRasterFR1;
bandRasterInfo = syncRasterInfo.(cfg.ssbCapture.band);
disp(bandRasterInfo)

rx.CenterFrequency = hSynchronizationRasterInfo.gscn2frequency(cfg.ssbCapture.gscn);
scsOptions = hSynchronizationRasterInfo.getSCSOptions(rx.CenterFrequency);
scs = scsOptions(1);

nrbSSB = 20;
scsNumeric = double(extract(scs,digitsPattern));
ofdmInfo = nrOFDMInfo(nrbSSB,scsNumeric);
rx.SampleRate = cfg.ssbCapture.sampleRate;

fprintf("Center frequency: %.2f MHz\n",rx.CenterFrequency/1e6);
fprintf("SSB SCS: %s\n",scs);
fprintf("Minimum SSB sample rate: %.2f MS/s\n",ofdmInfo.SampleRate/1e6);
fprintf("Configured sample rate: %.2f MS/s\n",rx.SampleRate/1e6);

framesPerCapture = cfg.ssbCapture.framesPerCapture;
captureDuration = seconds((framesPerCapture+1)*10e-3);
fprintf("Capture duration: %.1f ms\n",seconds(captureDuration)*1e3);

[waveform,captureTimestamp] = capture(rx,captureDuration);
assertValidCapture(waveform);
rxReleased = rx;
release(rxReleased);

[detectedSSB,ssbInfo,figureHandles] = findSSB(waveform,rxReleased.CenterFrequency,scs,rxReleased.SampleRate,cfg.ssbCapture.displayFigure);
outputFile = saveWaveform(rxReleased,waveform,scs,cfg.ssbCapture.fileNamePrefix,cfg.paths.dataRoot,ssbInfo,captureTimestamp,cfg);
figureFiles = strings(0,1);
if runOptions.saveFigures
    [~,captureName] = fileparts(outputFile);
    if strlength(runOptions.figureDir) == 0
        runOptions.figureDir = fullfile(cfg.paths.figuresRoot,captureName);
    end
    figureFiles = saveFigureSet(figureHandles,runOptions.figureDir,"ssb_capture",runOptions.figureFormat);
    if ~isempty(figureFiles)
        fprintf("Saved figure files:\n");
        fprintf("  %s\n",figureFiles);
    end
end

result = struct();
result.detectedSSB = detectedSSB;
result.ssbInfo = ssbInfo;
result.outputFile = outputFile;
result.captureTimestamp = captureTimestamp;
result.centerFrequencyHz = rxReleased.CenterFrequency;
result.sampleRate = rxReleased.SampleRate;
result.scs = scs;
result.figureFiles = figureFiles;

if detectedSSB
    fprintf("SSB detected. Saved MAT file: %s\n",outputFile);
else
    fprintf("No valid SSB detected. Saved raw capture MAT file: %s\n",outputFile);
end
end

function [configFile,overrides,runOptions] = parseInputs(varargin)
configFile = "";
overrides = struct();
runOptions = struct();
runOptions.saveFigures = false;
runOptions.figureDir = "";
runOptions.figureFormat = "pdf";

if isempty(varargin)
    return;
end
if isscalar(varargin) && isstruct(varargin{1})
    overrides = varargin{1};
    if isfield(overrides,"figures")
        if isfield(overrides.figures,"save")
            runOptions.saveFigures = logical(overrides.figures.save);
        end
        if isfield(overrides.figures,"format")
            runOptions.figureFormat = string(overrides.figures.format);
        end
    end
    return;
end
if mod(numel(varargin),2) ~= 0
    error("run1_capture_ssb_using_sdr:InvalidInputs", ...
        "Use name-value inputs, for example run1_capture_ssb_using_sdr(""SaveFigures"",true).");
end

for idx = 1:2:numel(varargin)
    name = lower(string(varargin{idx}));
    value = varargin{idx+1};
    switch name
        case {"savefigures","savefigure","save"}
            runOptions.saveFigures = parseLogical(value);
        case {"figuredir","outputfiguredir"}
            runOptions.figureDir = string(value);
        case {"figureformat","format"}
            runOptions.figureFormat = string(value);
        case {"config","configfile","profile"}
            configFile = string(value);
        case "overrides"
            overrides = value;
        otherwise
            error("run1_capture_ssb_using_sdr:UnknownOption", ...
                "Unknown option: %s.",name);
    end
end
end

function value = parseLogical(value)
if islogical(value)
    return;
end
if isnumeric(value)
    value = value ~= 0;
    return;
end
value = any(strcmpi(string(value),["true" "on" "yes" "1"]));
end

function releaseReceiver(rx)
if ~isempty(rx)
    try
        release(rx);
    catch
    end
end
end

function assertValidCapture(waveform)
if isempty(waveform) || size(waveform,1) == 0
    error("run1_capture_ssb_using_sdr:EmptyCapture", ...
        "SDR capture returned no samples. Check the preceding SDR/UHD warning before running SSB detection.");
end

hasNonzeroSamples = any(real(waveform(:)) ~= 0 | imag(waveform(:)) ~= 0);
if ~hasNonzeroSamples
    error("run1_capture_ssb_using_sdr:InvalidCapture", ...
        "SDR capture returned only zero samples. Check the preceding SDR/UHD warning before running SSB detection.");
end
end

function outputFile = saveWaveform(rx,waveform,scs,fileNamePrefix,dataRoot,ssbInfo,captureTimestamp,cfg)
%SAVEWAVEFORM Save a MIB/SIB1-recovery-compatible capture MAT file.
if ~isfolder(dataRoot)
    mkdir(dataRoot);
end

sampleRate = rx.SampleRate;
fPhaseComp = rx.CenterFrequency;
minChannelBW = hSynchronizationRasterInfo.getMinimumBandwidth(scs,rx.CenterFrequency);
ssbBlockPattern = hSynchronizationRasterInfo.getBlockPattern(scs,rx.CenterFrequency);
if fPhaseComp > 3e9
    L_max = 8;
else
    L_max = 4;
end

gscn = hSynchronizationRasterInfo.frequency2gscn(rx.CenterFrequency);
metadata = struct();
metadata.deviceName = cfg.ssbCapture.deviceName;
metadata.deviceAddress = string(rx.DeviceAddress);
metadata.gain = rx.Gain;
metadata.channelMapping = rx.ChannelMapping;
metadata.band = cfg.ssbCapture.band;
metadata.gscn = gscn;
metadata.captureTimestamp = captureTimestamp;
metadata.framesPerCapture = cfg.ssbCapture.framesPerCapture;
metadata.fileCreatedAt = datetime("now","TimeZone","local","Format","yyyy-MM-dd HH:mm:ss.SSS Z");

timestamp = string(datetime("now","Format","yyMMdd_HHmmss"));
fileName = fileNamePrefix+"_"+timestamp+".mat";
outputFile = fullfile(dataRoot,fileName);
save(outputFile,"waveform","sampleRate","fPhaseComp","minChannelBW", ...
    "ssbBlockPattern","L_max","metadata","ssbInfo","captureTimestamp","-v7.3");
end

function [detectedSSB,ssbInfo,figureHandles] = findSSB(waveform,centerFrequency,scs,sampleRate,displayFigure)
%FINDSSB Return true when WAVEFORM contains a valid SSB.
figureHandles = gobjects(0,1);
ssbBlockPattern = hSynchronizationRasterInfo.getBlockPattern(scs,centerFrequency);
scsNumeric = double(extract(scs,digitsPattern));
searchBW = 3*scsNumeric;
[correctedWaveform,freqOffset,NID2] = hSSBurstFrequencyCorrect(waveform,ssbBlockPattern,sampleRate,searchBW,false);

nrbSSB = 20;
refGrid = zeros([nrbSSB*12 2]);
refGrid(nrPSSIndices,2) = nrPSS(NID2);

nSlot = 0;
timingOffset = nrTimingEstimate(correctedWaveform,nrbSSB,scsNumeric,nSlot,refGrid,"SampleRate",sampleRate);
correctedWaveform = correctedWaveform(1+timingOffset:end,:);
rxGrid = nrOFDMDemodulate(correctedWaveform,nrbSSB,scsNumeric,nSlot,"SampleRate",sampleRate);
rxGrid = rxGrid(:,2:5,:);

sssIndices = nrSSSIndices;
sssRx = nrExtractResources(sssIndices,rxGrid);

sssEst = zeros(1,336);
for NID1 = 0:335
    ncellid = (3*NID1) + NID2;
    sssRef = nrSSS(ncellid);
    sssEst(NID1+1) = sum(abs(mean(sssRx .* conj(sssRef),1)).^2);
end

NID1 = find(sssEst==max(sssEst)) - 1;
ncellid = (3*NID1) + NID2;
dmrsIndices = nrPBCHDMRSIndices(ncellid);

dmrsEst = zeros(1,8);
for ibar_SSB = 0:7
    refGrid = zeros([240 4]);
    refGrid(dmrsIndices) = nrPBCHDMRS(ncellid,ibar_SSB);
    [hest,nest] = nrChannelEstimate(rxGrid,refGrid,"AveragingWindow",[0 1]);
    dmrsEst(ibar_SSB+1) = 10*log10(mean(abs(hest(:).^2)) / nest);
end

ibar_SSB = find(dmrsEst==max(dmrsEst)) - 1;
refGrid = zeros([nrbSSB*12 4]);
refGrid(dmrsIndices) = nrPBCHDMRS(ncellid,ibar_SSB);
refGrid(sssIndices) = nrSSS(ncellid);
[hest,nest] = nrChannelEstimate(rxGrid,refGrid,"AveragingWindow",[0 1]);

[pbchIndices,pbchIndicesInfo] = nrPBCHIndices(ncellid);
pbchRx = nrExtractResources(pbchIndices,rxGrid);
if centerFrequency <= 3e9
    L_max = 4;
    v = mod(ibar_SSB,L_max);
else
    L_max = 8;
    v = ibar_SSB;
end
ssbIndex = v;

pbchHest = nrExtractResources(pbchIndices,hest);
[pbchEq,csi] = nrEqualizeMMSE(pbchRx,pbchHest,nest);
Qm = pbchIndicesInfo.G / pbchIndicesInfo.Gd;
csi = repmat(csi.',Qm,1);
csi = reshape(csi,[],1);

pbchBits = nrPBCHDecode(pbchEq,ncellid,v,nest);
pbchBits = pbchBits .* csi;
polarListLength = 8;
[~,crcBCH] = nrBCHDecode(pbchBits,polarListLength,L_max,ncellid);

gscn = hSynchronizationRasterInfo.frequency2gscn(centerFrequency);
detectedSSB = (crcBCH == 0);

ssbInfo = struct();
ssbInfo.detectedSSB = detectedSSB;
ssbInfo.gscn = gscn;
ssbInfo.centerFrequencyHz = centerFrequency;
ssbInfo.scs = scs;
ssbInfo.ssbBlockPattern = ssbBlockPattern;
ssbInfo.frequencyOffsetHz = freqOffset;
ssbInfo.timingOffsetSamples = timingOffset;
ssbInfo.NID2 = NID2;
ssbInfo.NID1 = NID1;
ssbInfo.NCellID = ncellid;
ssbInfo.ibarSSB = ibar_SSB;
ssbInfo.ssbIndex = ssbIndex;
ssbInfo.pbchDmrsSnrDb = dmrsEst;
ssbInfo.bchCRC = crcBCH;
ssbInfo.pbchEqualizerCSI = csi;
ssbInfo.pbchChannelEstimate = pbchHest;
ssbInfo.pbchIndices = pbchIndices;
ssbInfo.pbchDmrsIndices = dmrsIndices;
ssbInfo.sssIndices = sssIndices;

if detectedSSB
    if displayFigure
        demodRB = 30;
        rxGrid = nrOFDMDemodulate(correctedWaveform,demodRB,scsNumeric,nSlot,"SampleRate",sampleRate);
        if size(rxGrid,2) < 56
            last = size(rxGrid,2);
        else
            last = 14*4;
        end
        fig = figure;
        figureHandles(end+1,1) = fig;
        imagesc(abs(rxGrid(:,1:last,1)));
        axis xy
        xlabel("OFDM symbol");
        ylabel("Subcarrier");
        ttl = sprintf("Resource Grid of SS Burst at GSCN %d (%.2f MHz)",gscn,centerFrequency/1e6);
        title(ttl)
        ssbFreqOrigin = 12*(demodRB-nrbSSB)/2 + 1;
        startSymbol = 1;
        numSymbolsSSB = 4;
        rectangle("Position",[startSymbol+0.5 ssbFreqOrigin-0.5 numSymbolsSSB 12*nrbSSB], ...
            "EdgeColor","r","LineWidth",1.5)
        str = sprintf("Strongest SSB: %d",ssbIndex);
        text(startSymbol,ssbFreqOrigin-nrbSSB,0,str,"FontSize",12,"Color","w");
        drawnow
    end
else
    fprintf("No SSB Detected at GSCN %d (%.2f MHz).\n",gscn,centerFrequency/1e6);
end
end
