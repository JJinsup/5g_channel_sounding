function recovery = run2_recover_mib_sib1_with_figures(varargin)
%RUN2_RECOVER_MIB_SIB1_WITH_FIGURES Run official MIB/SIB1 recovery with plots.
%   This interactive entry point mirrors the MathWorks
%   NRCellSearchMIBAndSIB1RecoveryExample behavior while using the project
%   wrapper to save a structured recovery result.
%
%   run2_recover_mib_sib1_with_figures("SaveFigures",true) saves generated
%   tutorial figures under outputs/figures/<capture-file-name>.

repoRoot = fileparts(mfilename("fullpath"));
addpath(fullfile(repoRoot,"config"));
addpath(fullfile(repoRoot,"src"));

%% User Settings
% Leave empty to use the latest capturedWaveform_*.mat or the fallback file.
configuredCaptureFile = "data/61.44_260507.mat";
configuredSaveFigures = false;

cfg = default_config(repoRoot);
[captureFile,runOptions] = parseInputs(varargin{:});
if strlength(string(captureFile)) == 0 && strlength(configuredCaptureFile) > 0
    captureFile = configuredCaptureFile;
end
if isempty(varargin)
    runOptions.saveFigures = configuredSaveFigures;
end
if strlength(string(captureFile)) == 0
    captureFile = chooseDefaultCaptureFile(repoRoot);
end

opts = struct();
opts.enablePlots = true;
opts.closeFiguresAfterRun = runOptions.closeFiguresAfterRun;
opts.minChannelBW = cfg.receiver.minChannelBW;
opts.saveResult = true;
opts.outputDir = cfg.paths.processedRoot;
opts.saveFigures = runOptions.saveFigures;
opts.figureFormat = runOptions.figureFormat;
if strlength(runOptions.figureDir) > 0
    opts.figureDir = runOptions.figureDir;
else
    opts.figureRoot = cfg.paths.figuresRoot;
end

recovery = recoverMibSib1FromCapture(captureFile,opts);
fprintf("%s",recovery.logText);
if strlength(recovery.error) > 0
    fprintf("%s\n",recovery.error);
end
if ~isempty(recovery.figureFiles)
    fprintf("Saved figure files:\n");
    fprintf("  %s\n",recovery.figureFiles);
end
end

function [captureFile,runOptions] = parseInputs(varargin)
captureFile = "";
runOptions = struct();
runOptions.saveFigures = false;
runOptions.figureDir = "";
runOptions.figureFormat = "pdf";
runOptions.closeFiguresAfterRun = false;

if isempty(varargin)
    return;
end

optionNames = ["savefigures" "savefigure" "save" "figuredir" ...
    "outputfiguredir" "figureformat" "format" "closefiguresafterrun"];
firstArg = lower(string(varargin{1}));
if ~any(firstArg == optionNames)
    captureFile = varargin{1};
    varargin = varargin(2:end);
end

if mod(numel(varargin),2) ~= 0
    error("run2_recover_mib_sib1_with_figures:InvalidInputs", ...
        "Use run2_recover_mib_sib1_with_figures(captureFile,""SaveFigures"",true).");
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
        otherwise
            error("run2_recover_mib_sib1_with_figures:UnknownOption", ...
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

function captureFile = chooseDefaultCaptureFile(repoRoot)
dataRoot = fullfile(repoRoot,"data");
capturedFiles = dir(fullfile(dataRoot,"capturedWaveform_*.mat"));
if ~isempty(capturedFiles)
    [~,idx] = max([capturedFiles.datenum]);
    captureFile = fullfile(capturedFiles(idx).folder,capturedFiles(idx).name);
    return;
end

fallback = fullfile(dataRoot,"61.44_260507.mat");
if isfile(fallback)
    captureFile = fallback;
    return;
end

allFiles = dir(fullfile(dataRoot,"*.mat"));
if isempty(allFiles)
    error("run2_recover_mib_sib1_with_figures:NoCaptureFile", ...
        "No MAT capture files found in %s.",dataRoot);
end
[~,idx] = max([allFiles.datenum]);
captureFile = fullfile(allFiles(idx).folder,allFiles(idx).name);
end
