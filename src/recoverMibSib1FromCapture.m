function recovery = recoverMibSib1FromCapture(captureFile, options)
%RECOVERMIBSIB1FROMCAPTURE Run the MathWorks MIB/SIB1 receiver on a MAT capture.
%   The receiver algorithm is intentionally the MathWorks
%   NRCellSearchMIBAndSIB1RecoveryExample flow. This wrapper only provides
%   project-friendly inputs, disables tutorial plots by default, and exports
%   decoded status plus CSI-related intermediate products.

if nargin < 1 || strlength(string(captureFile)) == 0
    captureFile = defaultCaptureFile();
end
if nargin < 2 || isempty(options)
    options = struct();
end

srcDir = fileparts(mfilename("fullpath"));
repoRoot = fileparts(srcDir);
addpath(srcDir);

captureFile = resolveCaptureFile(captureFile, repoRoot);
[~,captureName] = fileparts(captureFile);
scriptPath = fullfile(srcDir,"NRCellSearchMIBAndSIB1RecoveryExample.m"); %#ok<NASGU> Used by evalc/run below.

enablePlots = getOption(options,"enablePlots",false);
saveFigures = getOption(options,"saveFigures",false);
if saveFigures
    enablePlots = true;
end
minChannelBWOverride = getOption(options,"minChannelBW",40); %#ok<NASGU> Consumed by the MathWorks script.
closeFiguresAfterRun = getOption(options,"closeFiguresAfterRun",~enablePlots);
saveResult = getOption(options,"saveResult",false);
throwOnError = getOption(options,"throwOnError",false);
outputDir = string(getOption(options,"outputDir",fullfile(repoRoot,"outputs","2_processed")));
figureRoot = string(getOption(options,"figureRoot",fullfile(repoRoot,"outputs","2_processed","figures")));
figureDir = string(getOption(options,"figureDir",""));
if strlength(figureDir) == 0
    figureDir = fullfile(figureRoot,captureName);
end
figureFormat = string(getOption(options,"figureFormat","pdf"));
figurePrefix = string(getOption(options,"figurePrefix","mib_sib1"));
plotCsiFiguresEnabled = getOption(options,"plotCsiFigures",enablePlots || saveFigures);
extractCsirsCandidate = getOption(options,"extractCsirsCandidate",true);
csirsGridMode = string(getOption(options,"csirsGridMode","visible"));
csirsCarrierNSizeGrid = getOption(options,"csirsCarrierNSizeGrid",273);

recovery = struct();
recovery.captureFile = captureFile;
recovery.algorithm = "MathWorks NRCellSearchMIBAndSIB1RecoveryExample";
recovery.status = "started";
recovery.success = false;
recovery.error = "";
recovery.outputPath = "";
recovery.figureFiles = strings(0,1);

figuresBeforeRun = findall(groot,"Type","figure");
try
    logText = evalc('run(scriptPath);');
catch ME
    recovery.status = "error";
    recovery.error = string(ME.message);
    recovery.logText = string(getReport(ME,"basic","hyperlinks","off"));
    if closeFiguresAfterRun
        closeFigureSet(getCreatedFigures(figuresBeforeRun));
    end
    if throwOnError
        rethrow(ME);
    end
    return;
end

createdFigures = getCreatedFigures(figuresBeforeRun);
deferFigureSave = saveFigures && lower(figureFormat) == "pdf";
if saveFigures && ~deferFigureSave
    recovery.figureFiles = saveFigureSet(createdFigures,figureDir,figurePrefix,figureFormat);
end
if closeFiguresAfterRun && ~deferFigureSave
    closeFigureSet(createdFigures);
end

recovery.logText = string(logText);
recovery.status = "completed";

if exist("sampleRate","var")
    recovery.sampleRate = sampleRate;
end
if exist("fPhaseComp","var")
    recovery.fPhaseComp = fPhaseComp;
end
if exist("minChannelBW","var")
    recovery.minChannelBW = minChannelBW;
end
if exist("refBurst","var")
    recovery.refBurst = refBurst;
end

if exist("freqOffset","var") || exist("timingOffset","var") || exist("NID2","var") || exist("ncellid","var")
    recovery.sync = struct();
    if exist("freqOffset","var")
        recovery.sync.frequencyOffsetHz = freqOffset;
    end
    if exist("timingOffset","var")
        recovery.sync.timingOffsetSamples = timingOffset;
    end
    if exist("NID2","var")
        recovery.sync.NID2 = NID2;
    end
    if exist("ncellid","var")
        recovery.sync.NCellID = ncellid;
    end
end

if exist("dmrsEst","var") || exist("ibar_SSB","var") || exist("ssbIndex","var")
    recovery.ssb = struct();
    if exist("dmrsEst","var")
        recovery.ssb.pbchDmrsSnrDb = dmrsEst;
    end
    if exist("ibar_SSB","var")
        recovery.ssb.ibarSSB = ibar_SSB;
    end
    if exist("ssbIndex","var")
        recovery.ssb.ssbIndex = ssbIndex;
    end
end

if exist("crcBCH","var") || exist("pbchEVMrms","var") || exist("mib","var") || exist("initialSystemInfo","var")
    recovery.mib = struct();
    if exist("crcBCH","var")
        recovery.mib.bchCRC = crcBCH;
    end
    if exist("pbchEVMrms","var")
        recovery.mib.pbchEVMrmsPercent = pbchEVMrms;
    end
    if exist("mib","var")
        recovery.mib.decodedMIB = mib;
    end
    if exist("initialSystemInfo","var")
        recovery.mib.initialSystemInfo = initialSystemInfo;
    end
end

if exist("dciCRC","var") || exist("pdcchEVMrms","var") || exist("dci","var")
    recovery.pdcch = struct();
    if exist("dciCRC","var")
        recovery.pdcch.dciCRC = dciCRC;
    end
    if exist("pdcchEVMrms","var")
        recovery.pdcch.pdcchEVMrmsPercent = pdcchEVMrms;
    end
    if exist("dci","var")
        recovery.pdcch.dci = dci;
    end
end

if exist("sib1CRC","var") || exist("pdschEVMrms","var") || exist("pdsch","var")
    recovery.sib1 = struct();
    if exist("sib1CRC","var")
        recovery.sib1.crc = sib1CRC;
        recovery.success = (sib1CRC == 0);
        if recovery.success
            recovery.status = "sib1_succeeded";
        else
            recovery.status = "sib1_failed";
        end
    end
    if exist("pdschEVMrms","var")
        recovery.sib1.pdschEVMrmsPercent = pdschEVMrms;
    end
    if exist("pdsch","var")
        recovery.sib1.pdsch = pdsch;
    end
end

recovery.csi = struct();
if exist("csi","var")
    recovery.csi.pbchEqualizerCSI = csi;
end
if exist("pbchHest","var")
    recovery.csi.pbchChannelEstimate = pbchHest;
end
if exist("hestInfo","var")
    recovery.csi.pbchChannelEstimateInfo = hestInfo;
end
if exist("pdschHest","var")
    recovery.csi.pdschChannelEstimate = pdschHest;
end
if exist("pdschHestInfo","var")
    recovery.csi.pdschChannelEstimateInfo = pdschHestInfo;
end
if exist("pbchIndices","var")
    recovery.csi.pbchIndices = pbchIndices;
end
if exist("dmrsIndices","var")
    recovery.csi.pbchDmrsIndices = dmrsIndices;
end
if exist("sssIndices","var")
    recovery.csi.sssIndices = sssIndices;
end
if exist("pdschDmrsIndices","var")
    recovery.csi.pdschDmrsIndices = pdschDmrsIndices;
end
if exist("pdschIndices","var")
    recovery.csi.pdschIndices = pdschIndices;
end

if exist("ssbGrid","var") && exist("dmrsIndices","var") && exist("ncellid","var") && exist("ibar_SSB","var")
    pbchDmrsSymbols = nrPBCHDMRS(ncellid,ibar_SSB);
    pbchDmrsRx = nrExtractResources(dmrsIndices,ssbGrid);
    pbchDmrsLsEstimate = pbchDmrsRx ./ pbchDmrsSymbols;
    pbchDmrsSparseGrid = nan(size(ssbGrid),"like",ssbGrid);
    pbchDmrsSparseGrid(dmrsIndices) = pbchDmrsLsEstimate;
    pbchDmrsMask = false(size(ssbGrid));
    pbchDmrsMask(dmrsIndices) = true;

    recovery.csi.pbchDmrsLs = struct();
    recovery.csi.pbchDmrsLs.source = "PBCH DM-RS";
    recovery.csi.pbchDmrsLs.description = "Sparse LS CSI from the official SSB/PBCH DM-RS hypothesis: H = Y_DMRS / X_DMRS.";
    recovery.csi.pbchDmrsLs.NCellID = ncellid;
    recovery.csi.pbchDmrsLs.ibarSSB = ibar_SSB;
    if exist("ssbIndex","var")
        recovery.csi.pbchDmrsLs.ssbIndex = ssbIndex;
    end
    recovery.csi.pbchDmrsLs.indices = dmrsIndices;
    recovery.csi.pbchDmrsLs.rxSymbols = pbchDmrsRx;
    recovery.csi.pbchDmrsLs.txSymbols = pbchDmrsSymbols;
    recovery.csi.pbchDmrsLs.lsEstimate = pbchDmrsLsEstimate;
    recovery.csi.pbchDmrsLs.sparseGrid = pbchDmrsSparseGrid;
    recovery.csi.pbchDmrsLs.referenceMask = pbchDmrsMask;
    recovery.csi.pbchDmrsLs.ssbGridSize = size(ssbGrid);
    recovery.csi.pbchDmrsLs.validRefReCount = numel(pbchDmrsLsEstimate);
    recovery.csi.pbchDmrsLs.meanAbsEstimate = mean(abs(pbchDmrsLsEstimate));
    recovery.csi.pbchDmrsLs.maxAbsEstimate = max(abs(pbchDmrsLsEstimate));
    if exist("ssbChannelGrid","var")
        recovery.csi.pbchDmrsLs.officialChannelGrid = ssbChannelGrid;
    end
    if exist("ssbNoiseVariance","var")
        recovery.csi.pbchDmrsLs.noiseVariance = ssbNoiseVariance;
    end
    if exist("ssbChannelEstimateInfo","var")
        recovery.csi.pbchDmrsLs.channelEstimateInfo = ssbChannelEstimateInfo;
    end
end

if exist("rxSlotGrid","var") && exist("pdschDmrsIndices","var") && exist("pdschDmrsSymbols","var")
    pdschDmrsRx = nrExtractResources(pdschDmrsIndices,rxSlotGrid);
    pdschDmrsLsEstimate = pdschDmrsRx ./ pdschDmrsSymbols;
    pdschDmrsSparseGrid = nan(size(rxSlotGrid),"like",rxSlotGrid);
    pdschDmrsSparseGrid(pdschDmrsIndices) = pdschDmrsLsEstimate;
    pdschDmrsMask = false(size(rxSlotGrid));
    pdschDmrsMask(pdschDmrsIndices) = true;

    recovery.csi.pdschDmrsLs = struct();
    recovery.csi.pdschDmrsLs.source = "SIB1 PDSCH DM-RS";
    recovery.csi.pdschDmrsLs.description = "Sparse LS CSI from the official SIB1 PDSCH DM-RS configuration: H = Y_DMRS / X_DMRS.";
    if exist("ncellid","var")
        recovery.csi.pdschDmrsLs.NCellID = ncellid;
    end
    recovery.csi.pdschDmrsLs.indices = pdschDmrsIndices;
    recovery.csi.pdschDmrsLs.rxSymbols = pdschDmrsRx;
    recovery.csi.pdschDmrsLs.txSymbols = pdschDmrsSymbols;
    recovery.csi.pdschDmrsLs.lsEstimate = pdschDmrsLsEstimate;
    recovery.csi.pdschDmrsLs.sparseGrid = pdschDmrsSparseGrid;
    recovery.csi.pdschDmrsLs.referenceMask = pdschDmrsMask;
    recovery.csi.pdschDmrsLs.slotGridSize = size(rxSlotGrid);
    recovery.csi.pdschDmrsLs.validRefReCount = numel(pdschDmrsLsEstimate);
    recovery.csi.pdschDmrsLs.meanAbsEstimate = mean(abs(pdschDmrsLsEstimate));
    recovery.csi.pdschDmrsLs.maxAbsEstimate = max(abs(pdschDmrsLsEstimate));
    if exist("pdschChannelGrid","var")
        recovery.csi.pdschDmrsLs.officialChannelGrid = pdschChannelGrid;
    end
    if exist("pdschNoiseVariance","var")
        recovery.csi.pdschDmrsLs.noiseVariance = pdschNoiseVariance;
    end
    if exist("pdschHestInfo","var")
        recovery.csi.pdschDmrsLs.channelEstimateInfo = pdschHestInfo;
    end
    if exist("pdsch","var")
        recovery.csi.pdschDmrsLs.pdsch = pdsch;
    end
    if exist("carrier","var")
        recovery.csi.pdschDmrsLs.carrier = carrier;
    end
end

if extractCsirsCandidate && exist("rxGrid","var") && exist("ncellid","var") && ...
        exist("scsCommon","var") && exist("initialSystemInfo","var")
    csirsRxGrid = rxGrid;
    csirsGridInfo = defaultCsirsGridInfo(csirsGridMode,rxGrid);
    if exist("rxWave","var") && exist("sampleRate","var") && exist("fPhaseComp","var")
        [csirsRxGrid,csirsGridInfo] = buildCsirsExtractionGrid(rxGrid,rxWave, ...
            sampleRate,fPhaseComp,scsCommon,csirsGridMode,csirsCarrierNSizeGrid);
    end
    recovery.csi.csirsCandidate = extractCsirsCandidateCsi(csirsRxGrid,ncellid,scsCommon,initialSystemInfo);
    recovery.csi.csirsCandidate.extractionGrid = csirsGridInfo;
end

if plotCsiFiguresEnabled
    csiFigureHandles = plotCsiFigures(recovery.csi);
    if saveFigures && ~deferFigureSave
        csiFigureFiles = saveFigureSet(csiFigureHandles,figureDir,"csi",figureFormat);
        recovery.figureFiles = [recovery.figureFiles; csiFigureFiles];
    end
    if closeFiguresAfterRun && ~deferFigureSave
        closeFigureSet(csiFigureHandles);
    end
end

if deferFigureSave
    if plotCsiFiguresEnabled
        allFigureHandles = [createdFigures; csiFigureHandles];
    else
        allFigureHandles = createdFigures;
    end
    recovery.figureFiles = saveFigureSet(allFigureHandles,figureDir,"figures",figureFormat);
    if closeFiguresAfterRun
        closeFigureSet(allFigureHandles);
    end
end

if ~recovery.success && recovery.status == "completed"
    if contains(recovery.logText,"CORESET 0 resources are beyond")
        recovery.status = "insufficient_sample_rate_for_coreset0";
    elseif contains(recovery.logText,"DCI decoding failed")
        recovery.status = "dci_failed";
    elseif contains(recovery.logText,"BCH CRC is not zero")
        recovery.status = "bch_failed";
    elseif contains(recovery.logText,"CORESET 0 is not present")
        recovery.status = "coreset0_not_present";
    elseif contains(recovery.logText,"Search space slot is beyond end of waveform")
        recovery.status = "search_space_beyond_waveform";
    end
end

if saveResult
    if ~isfolder(outputDir)
        mkdir(outputDir);
    end
    recovery.outputPath = fullfile(outputDir,captureName + "_mib_sib1_recovery.mat");
    save(recovery.outputPath,"recovery","-v7.3");
end
end

function createdFigures = getCreatedFigures(figuresBeforeRun)
allFigures = findall(groot,"Type","figure");
createdMask = true(size(allFigures));
for idx = 1:numel(allFigures)
    createdMask(idx) = ~any(allFigures(idx) == figuresBeforeRun);
end
createdFigures = allFigures(createdMask);
end

function closeFigureSet(figures)
for idx = 1:numel(figures)
    if isgraphics(figures(idx),"figure")
        close(figures(idx));
    end
end
end

function [csirsGrid,gridInfo] = buildCsirsExtractionGrid(visibleGrid,rxWave,sampleRate,fPhaseComp,scsCommon,gridMode,carrierNSizeGrid)
csirsGrid = visibleGrid;
gridInfo = defaultCsirsGridInfo(gridMode,visibleGrid);
gridMode = lower(string(gridMode));
carrierNSizeGrid = double(carrierNSizeGrid);

if ~any(gridMode == ["carrier" "full" "fullcarrier"])
    return;
end

requiredSampleRate = carrierNSizeGrid*12*scsCommon*1e3;
gridInfo.requestedNSizeGrid = carrierNSizeGrid;
gridInfo.requiredSampleRate = requiredSampleRate;
if sampleRate < requiredSampleRate
    gridInfo.source = "visible_grid_fallback";
    gridInfo.fallbackReason = sprintf("Sample rate %.2f MS/s is below %.2f MS/s required for %d RB at %d kHz SCS.", ...
        sampleRate/1e6,requiredSampleRate/1e6,carrierNSizeGrid,scsCommon);
    return;
end

csirsGrid = nrOFDMDemodulate(rxWave,carrierNSizeGrid,scsCommon,0, ...
    "SampleRate",sampleRate,"CarrierFrequency",fPhaseComp);
gridInfo.source = "carrier_grid";
gridInfo.appliedNSizeGrid = carrierNSizeGrid;
gridInfo.gridSize = size(csirsGrid);
gridInfo.fallbackReason = "";
end

function gridInfo = defaultCsirsGridInfo(gridMode,visibleGrid)
gridInfo = struct();
gridInfo.requestedMode = string(gridMode);
gridInfo.source = "visible_grid";
gridInfo.requestedNSizeGrid = NaN;
gridInfo.appliedNSizeGrid = floor(size(visibleGrid,1)/12);
gridInfo.requiredSampleRate = NaN;
gridInfo.gridSize = size(visibleGrid);
gridInfo.fallbackReason = "";
end

function value = getOption(options, name, defaultValue)
name = char(name);
if isfield(options,name)
    value = options.(name);
else
    value = defaultValue;
end
end

function captureFile = defaultCaptureFile()
srcDir = fileparts(mfilename("fullpath"));
captureFile = fullfile(srcDir,"..","outputs","1_IQcapture","61.44_260507.mat");
end

function resolved = resolveCaptureFile(captureFile, repoRoot)
captureFile = string(captureFile);
if startsWith(captureFile,filesep)
    resolved = captureFile;
    return;
end
if isfile(captureFile)
    resolved = string(fullfile(pwd,captureFile));
    return;
end

candidate = string(fullfile(repoRoot,captureFile));
if isfile(candidate)
    resolved = candidate;
else
    resolved = captureFile;
end
end
