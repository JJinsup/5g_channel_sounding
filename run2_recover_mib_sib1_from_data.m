function batchResult = run2_recover_mib_sib1_from_data(varargin)
%RUN2_RECOVER_MIB_SIB1_FROM_DATA Batch MIB/SIB1 recovery for saved captures.
%   This is the offline analysis entry point for real captured MAT files.
%   It uses the MathWorks receiver flow through recoverMibSib1FromCapture.
%
%   run2_recover_mib_sib1_from_data("SaveFigures",true) saves generated
%   tutorial figures under outputs/2_processed/figures/<capture-file-name>.

repoRoot = fileparts(mfilename("fullpath"));
addpath(fullfile(repoRoot,"config"));
addpath(fullfile(repoRoot,"src"));

%% User Settings
configuredConfigFile = "config/b210_config.m";
% Leave empty to analyze every MAT file under outputs/1_IQcapture/.
configuredDataFiles = "outputs/1_IQcapture/61.44_260507.mat";
configuredSaveFigures = true;

[dataFiles,runOptions] = parseInputs(varargin{:});
configFile = runOptions.configFile;
if strlength(configFile) == 0
    configFile = configuredConfigFile;
end
cfg = load_project_config(repoRoot,configFile);
if isempty(dataFiles) && ~isempty(configuredDataFiles)
    dataFiles = configuredDataFiles;
end
if isempty(varargin)
    runOptions.saveFigures = configuredSaveFigures;
end

if isempty(dataFiles)
    dataFiles = listCaptureFiles(cfg.paths.dataRoot);
end

if isempty(dataFiles)
    error("run2_recover_mib_sib1_from_data:NoData", ...
        "No MAT capture files were found.");
end

opts = struct();
opts.enablePlots = cfg.receiver.enablePlots || runOptions.saveFigures;
opts.closeFiguresAfterRun = runOptions.closeFiguresAfterRun;
opts.minChannelBW = cfg.receiver.minChannelBW;
opts.extractCsirsCandidate = cfg.receiver.extractCsirsCandidate;
opts.csirsGridMode = cfg.receiver.csirsGridMode;
opts.csirsCarrierNSizeGrid = cfg.receiver.csirsCarrierNSizeGrid;
opts.saveResult = true;
opts.outputDir = cfg.paths.processedRoot;
opts.saveFigures = runOptions.saveFigures;
opts.figureFormat = runOptions.figureFormat;
if strlength(runOptions.figureDir) > 0
    opts.figureDir = runOptions.figureDir;
else
    opts.figureRoot = cfg.paths.figuresRoot;
end

if ~isfolder(opts.outputDir)
    mkdir(opts.outputDir);
end

summaryRows = cell(numel(dataFiles),1);
fprintf("=== MIB/SIB1 Recovery Batch Start ===\n");

for idx = 1:numel(dataFiles)
    fprintf("\n--- %d / %d: %s ---\n",idx,numel(dataFiles),dataFiles(idx));
    recovery = recoverMibSib1FromCapture(dataFiles(idx),opts);
    summaryRows{idx} = summarizeRecovery(recovery);
    fprintf("Status: %s\n",recovery.status);
end

summaryTable = struct2table([summaryRows{:}]');
processedRoot = cfg.paths.processedRoot;
if ~isfolder(processedRoot)
    mkdir(processedRoot);
end
outputPath = fullfile(processedRoot, ...
    "mib_sib1_batch_" + string(datetime("now","Format","yyyyMMdd_HHmmss")) + ".mat");
save(outputPath,"summaryTable","dataFiles","-v7.3");

batchResult = struct();
batchResult.summaryTable = summaryTable;
batchResult.outputPath = outputPath;
batchResult.dataFiles = dataFiles;

fprintf("\n=== MIB/SIB1 Recovery Batch Summary ===\n");
disp(summaryTable(:,["captureFile","status","success","sampleRateMsps", ...
    "ncellid","ssbIndex","bchCRC","dciCRC","sib1CRC", ...
    "pbchDmrsCsiRefs","pdschDmrsCsiRefs","csirsCandidateCsiRefs", ...
    "figureFileCount","resultFile"]));
fprintf("Saved batch summary: %s\n",outputPath);
end

function [dataFiles,runOptions] = parseInputs(varargin)
dataFiles = strings(0,1);
runOptions = struct();
runOptions.saveFigures = false;
runOptions.figureDir = "";
runOptions.figureFormat = "pdf";
runOptions.closeFiguresAfterRun = true;
runOptions.configFile = "";

if isempty(varargin)
    return;
end

optionNames = ["savefigures" "savefigure" "save" "figuredir" ...
    "outputfiguredir" "figureformat" "format" "closefiguresafterrun" ...
    "config" "configfile" "profile"];
firstArg = lower(string(varargin{1}));
if ~any(firstArg == optionNames)
    dataFiles = string(varargin{1});
    varargin = varargin(2:end);
end

if mod(numel(varargin),2) ~= 0
    error("run2_recover_mib_sib1_from_data:InvalidInputs", ...
        "Use run2_recover_mib_sib1_from_data(dataFiles,""SaveFigures"",true).");
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
        case "closefiguresafterrun"
            runOptions.closeFiguresAfterRun = parseLogical(value);
        case {"config","configfile","profile"}
            runOptions.configFile = string(value);
        otherwise
            error("run2_recover_mib_sib1_from_data:UnknownOption", ...
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

function dataFiles = listCaptureFiles(dataRoot)
dataFiles = strings(0,1);
listing = dir(fullfile(dataRoot,"*.mat"));
if isempty(listing)
    return;
end
dataFiles = strings(numel(listing),1);
for idx = 1:numel(listing)
    dataFiles(idx) = string(fullfile(listing(idx).folder,listing(idx).name));
end
end

function row = summarizeRecovery(recovery)
row = struct();
row.captureFile = recovery.captureFile;
row.status = recovery.status;
row.success = recovery.success;
row.error = recovery.error;
row.sampleRateMsps = NaN;
row.frequencyOffsetHz = NaN;
row.timingOffsetSamples = NaN;
row.ncellid = NaN;
row.ssbIndex = NaN;
row.pbchEVMrmsPercent = NaN;
row.bchCRC = NaN;
row.pdcchEVMrmsPercent = NaN;
row.dciCRC = NaN;
row.pdschEVMrmsPercent = NaN;
row.sib1CRC = NaN;
row.pbchDmrsCsiRefs = NaN;
row.pdschDmrsCsiRefs = NaN;
row.csirsCandidateCsiRefs = NaN;
row.figureFileCount = 0;
row.resultFile = recovery.outputPath;

if isfield(recovery,"sampleRate")
    row.sampleRateMsps = recovery.sampleRate / 1e6;
end
if isfield(recovery,"sync")
    if isfield(recovery.sync,"frequencyOffsetHz")
        row.frequencyOffsetHz = recovery.sync.frequencyOffsetHz;
    end
    if isfield(recovery.sync,"timingOffsetSamples")
        row.timingOffsetSamples = recovery.sync.timingOffsetSamples;
    end
    if isfield(recovery.sync,"NCellID")
        row.ncellid = recovery.sync.NCellID;
    end
end
if isfield(recovery,"ssb") && isfield(recovery.ssb,"ssbIndex")
    row.ssbIndex = recovery.ssb.ssbIndex;
end
if isfield(recovery,"mib")
    if isfield(recovery.mib,"pbchEVMrmsPercent")
        row.pbchEVMrmsPercent = recovery.mib.pbchEVMrmsPercent;
    end
    if isfield(recovery.mib,"bchCRC")
        row.bchCRC = double(recovery.mib.bchCRC);
    end
end
if isfield(recovery,"pdcch")
    if isfield(recovery.pdcch,"pdcchEVMrmsPercent")
        row.pdcchEVMrmsPercent = recovery.pdcch.pdcchEVMrmsPercent;
    end
    if isfield(recovery.pdcch,"dciCRC")
        row.dciCRC = double(recovery.pdcch.dciCRC);
    end
end
if isfield(recovery,"sib1")
    if isfield(recovery.sib1,"pdschEVMrmsPercent")
        row.pdschEVMrmsPercent = recovery.sib1.pdschEVMrmsPercent;
    end
    if isfield(recovery.sib1,"crc")
        row.sib1CRC = double(recovery.sib1.crc);
    end
end
if isfield(recovery,"csi")
    if isfield(recovery.csi,"pbchDmrsLs")
        row.pbchDmrsCsiRefs = recovery.csi.pbchDmrsLs.validRefReCount;
    end
    if isfield(recovery.csi,"pdschDmrsLs")
        row.pdschDmrsCsiRefs = recovery.csi.pdschDmrsLs.validRefReCount;
    end
    if isfield(recovery.csi,"csirsCandidate")
        row.csirsCandidateCsiRefs = recovery.csi.csirsCandidate.validRefReCount;
    end
end
if isfield(recovery,"figureFiles")
    row.figureFileCount = numel(recovery.figureFiles);
end
end
