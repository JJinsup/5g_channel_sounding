function cfg = default_config(repoRoot, overrides)
%DEFAULT_CONFIG Main configuration for the MathWorks-example-based workflow.
%   Keep this file focused on SSB capture, MIB/SIB1 recovery, and DM-RS CSI.

if nargin == 0 || isempty(repoRoot)
    repoRoot = pwd;
end
if nargin < 2
    overrides = struct();
end

cfg = struct();
cfg.projectName = 'official_example_based_5g_csi';

cfg.radio = struct();
cfg.radio.serialNum = '3275420';
cfg.radio.gain = 35;
cfg.radio.channelMapping = 1;
cfg.radio.outputDataType = 'single';

cfg.ssbCapture = struct();
cfg.ssbCapture.deviceName = "B210";
cfg.ssbCapture.band = "n79";
cfg.ssbCapture.gscn = 8720;
cfg.ssbCapture.sampleRate = 61.44e6;

% MathWorks SSB capture style: capture duration = (framesPerCapture + 1)*10 ms.
cfg.ssbCapture.framesPerCapture = 5;
cfg.ssbCapture.fileNamePrefix = "capturedWaveform";
cfg.ssbCapture.displayFigure = true;

cfg.receiver = struct();
cfg.receiver.minChannelBW = 40; % n79 100 MHz deployment; CORESET 0 table selector.
cfg.receiver.enablePlots = false; % Batch recovery should not open tutorial figures.

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
