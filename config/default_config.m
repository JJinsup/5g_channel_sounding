function cfg = default_config(repoRoot, overrides)
%DEFAULT_CONFIG Default configuration for first-pass passive NR capture.
%   All main experiment parameters should be edited here first. Optional
%   overrides can be passed as a struct with matching nested fields.

if nargin == 0 || isempty(repoRoot)
    repoRoot = pwd;
end
if nargin < 2
    overrides = struct();
end

cfg = struct();
cfg.projectName = 'passive_nr_downlink_capture';

cfg.radio = struct();
cfg.radio.platform = 'B210';

% Set SerialNum when multiple USRPs are connected.
cfg.radio.serialNum = '33A6D7D';

% Primary semi-guided target from the project brief.
cfg.radio.arfcn = 717216;

% Leave empty to derive center frequency from ARFCN.
% Set a value such as 4758.24e6 to manually override.
cfg.radio.centerFrequencyOverrideHz = [];
cfg.radio.centerFrequencyHz = resolveCenterFrequency(cfg.radio.arfcn, cfg.radio.centerFrequencyOverrideHz);

% Start with 15.36 MSps for first-pass validation on B210.
cfg.radio.sampleRate = 15.36e6;
cfg.radio.masterClockRate = 15.36e6;
cfg.radio.gain = 35;
cfg.radio.channelMapping = 1;
cfg.radio.outputDataType = 'single';

% GPSDO is currently not locked, so use Internal sources by default.
% To retry GPSDO later, change both values to 'GPSDO'.
cfg.radio.clockSource = 'Internal';
cfg.radio.ppsSource = 'Internal';

cfg.capture = struct();
cfg.capture.durationMs = 15;
cfg.capture.samplesPerFrame = 8192;
cfg.capture.enableBurstMode = true;
cfg.capture.numFrames = ceil((cfg.capture.durationMs * 1e-3 * cfg.radio.sampleRate) / cfg.capture.samplesPerFrame);
cfg.capture.expectedSamples = cfg.capture.numFrames * cfg.capture.samplesPerFrame;

cfg.search = struct();
cfg.search.defaultSCSkHz = 30;
cfg.search.fallbackSCSkHz = [60 15];
cfg.search.pciCandidates = [1003 1004 1002];
% Leave empty for normal semi-guided ranking across all candidates.
% Set to a scalar such as 1003 to force one PCI during debug analysis.
cfg.search.forcePCI = [];
cfg.search.ssBurstNSizeGrid = 20;
cfg.search.initialSlot = 0;
cfg.search.minPeakToMedianRatio = 4.0;
cfg.search.minPeakPowerDb = -50;

cfg.sync = struct();
cfg.sync.initialSlot = 0;
cfg.sync.minWaveformSamples = 4096;
cfg.sync.enableCfoCorrection = true;
cfg.sync.cfoMaxSymbols = 8;
% Optional residual correction applied after timing trim / CFO correction
% and immediately before OFDM demodulation. Start at zero and tune during
% phase-flattening debug.
cfg.sync.residualCfoHz = 0;
cfg.sync.residualTimingSamples = 0;
cfg.sync.enablePbchPhaseRefinement = true;
cfg.sync.maxAutoResidualTimingSamples = 8;
cfg.sync.autoResidualTimingSigns = [-1 1];

cfg.grid = struct();
cfg.grid.nSizeGrid = 20;
cfg.grid.nStartGrid = 0;
cfg.grid.cyclicPrefix = 'normal';

cfg.pbch = struct();
cfg.pbch.dmrsIbarSsb = 0;

cfg.cir = struct();
cfg.cir.window = 'hamming';
cfg.cir.zeroPadFactor = 4;
cfg.cir.tapThresholdDb = -20;
cfg.cir.phaseFitMagnitudeFraction = 0.5;
cfg.cir.edgeTrimFraction = 0.08;

cfg.diagnostics = struct();
cfg.diagnostics.figureVisibility = 'off';
cfg.diagnostics.spectrumNfft = 4096;
cfg.diagnostics.psdSegmentLength = 2048;
cfg.diagnostics.maxPsdSegments = 64;
cfg.diagnostics.timePreviewSamples = 4000;
cfg.diagnostics.histogramBins = 80;
cfg.diagnostics.clipLevel = 0.95;
cfg.diagnostics.saveFigures = true;

cfg.export = struct();
cfg.export.saveProcessedMat = true;

cfg.paths = struct();
cfg.paths.outputRoot = fullfile(repoRoot, 'outputs');
cfg.paths.rawIqRoot = fullfile(cfg.paths.outputRoot, 'raw_iq');
cfg.paths.processedRoot = fullfile(cfg.paths.outputRoot, 'processed');
cfg.paths.figuresRoot = fullfile(cfg.paths.outputRoot, 'figures');
cfg.paths.logsRoot = fullfile(cfg.paths.outputRoot, 'logs');

cfg.metadata = struct();
cfg.metadata.plmn = '450-40';
cfg.metadata.band = 'n79';
cfg.metadata.notes = 'Initial hardware validation capture';

cfg = applyOverrides(cfg, overrides);
cfg = finalizeDerivedFields(cfg);
end

function centerFrequencyHz = resolveCenterFrequency(arfcn, overrideHz)
if ~isempty(overrideHz)
    centerFrequencyHz = overrideHz;
    return;
end

centerFrequencyHz = nrArfcnToHz(arfcn);
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

function cfg = finalizeDerivedFields(cfg)
if ~isempty(cfg.radio.centerFrequencyOverrideHz)
    cfg.radio.centerFrequencyHz = cfg.radio.centerFrequencyOverrideHz;
else
    cfg.radio.centerFrequencyHz = nrArfcnToHz(cfg.radio.arfcn);
end

cfg.capture.numFrames = ceil((cfg.capture.durationMs * 1e-3 * cfg.radio.sampleRate) / cfg.capture.samplesPerFrame);
cfg.capture.expectedSamples = cfg.capture.numFrames * cfg.capture.samplesPerFrame;
end
