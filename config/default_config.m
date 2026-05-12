function cfg = default_config(repoRoot, overrides)
%DEFAULT_CONFIG Main configuration for the MathWorks-example-based workflow.
%   Keep this file focused on SSB capture, MIB/SIB1 recovery, and CSI.

if nargin == 0 || isempty(repoRoot)
    repoRoot = pwd;
end
if nargin < 2
    overrides = struct();
end

cfg = struct();
cfg.projectName = 'official_example_based_5g_csi';

cfg.radio = struct();
cfg.radio.deviceSeries = "auto"; % auto, b200, or x300. Controls safe capture/CSI-RS defaults.
cfg.radio.serialNum = '3275420';
cfg.radio.gain = 35;
cfg.radio.channelMapping = 1;
cfg.radio.outputDataType = 'single';

cfg.ssbCapture = struct();
cfg.ssbCapture.deviceName = "B210";
cfg.ssbCapture.band = "n79";
cfg.ssbCapture.gscn = 8720;
cfg.ssbCapture.sampleRate = [];

% MathWorks SSB capture style: capture duration = (framesPerCapture + 1)*10 ms.
cfg.ssbCapture.framesPerCapture = 5;
cfg.ssbCapture.fileNamePrefix = "capturedWaveform";
cfg.ssbCapture.displayFigure = true;

cfg.receiver = struct();
cfg.receiver.minChannelBW = 40; % n79 100 MHz deployment; CORESET 0 table selector.
cfg.receiver.enablePlots = false; % Batch recovery should not open tutorial figures.
cfg.receiver.extractCsirsCandidate = true; % Hypothesis-based TRS/NZP CSI-RS LS CSI.
cfg.receiver.csirsGridMode = "auto"; % auto: B-series visible grid, X-series carrier grid.
cfg.receiver.csirsCarrierNSizeGrid = 273; % n79 100 MHz at 30 kHz SCS.

cfg.paths = struct();
cfg.paths.outputRoot = fullfile(repoRoot,"outputs");
cfg.paths.dataRoot = fullfile(cfg.paths.outputRoot,"1_IQcapture");
cfg.paths.processedRoot = fullfile(cfg.paths.outputRoot,"2_processed");
cfg.paths.validationRoot = fullfile(cfg.paths.outputRoot,"3_validation");
cfg.paths.figuresRoot = fullfile(cfg.paths.processedRoot,"figures");

cfg.figures = struct();
cfg.figures.save = false;
cfg.figures.format = "pdf";

cfg = applyOverrides(cfg, overrides);
cfg = applyRadioProfileDefaults(cfg);
end

function cfg = applyRadioProfileDefaults(cfg)
series = inferRadioSeries(cfg);
cfg.radio.deviceSeries = series;

if isempty(cfg.ssbCapture.sampleRate) || cfg.ssbCapture.sampleRate == 0
    switch series
        case "x300"
            cfg.ssbCapture.sampleRate = 184.32e6;
        otherwise
            cfg.ssbCapture.sampleRate = 61.44e6;
    end
end

if lower(string(cfg.receiver.csirsGridMode)) == "auto"
    switch series
        case "x300"
            cfg.receiver.csirsGridMode = "carrier";
        otherwise
            cfg.receiver.csirsGridMode = "visible";
    end
end
end

function series = inferRadioSeries(cfg)
configured = lower(string(cfg.radio.deviceSeries));
if configured ~= "auto" && strlength(configured) > 0
    series = configured;
    return;
end

deviceName = upper(string(cfg.ssbCapture.deviceName));
if any(deviceName == ["X300" "X310"])
    series = "x300";
elseif any(deviceName == ["B200" "B210"])
    series = "b200";
else
    series = "other";
end
end

function cfg = applyOverrides(cfg, overrides)
if isempty(overrides)
    return;
end

fields = fieldnames(overrides);
for idx = 1:numel(fields)
    fieldName = fields{idx};
    overrideValue = overrides.(fieldName);
    if isstruct(overrideValue) && isfield(cfg, fieldName) && isstruct(cfg.(fieldName))
        cfg.(fieldName) = applyOverrides(cfg.(fieldName), overrideValue);
    else
        cfg.(fieldName) = overrideValue;
    end
end
end
