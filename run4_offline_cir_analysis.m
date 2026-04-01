function cirAnalysisResult = run4_offline_cir_analysis(captureMatPath)
%RUN4_OFFLINE_CIR_ANALYSIS Run PBCH-DMRS-based sparse observation, surrogate CFR, and surrogate CIR analysis.
%   With no input, analyze two code-selected representative captures so
%   CSI/CIR debugging can stay focused on a good/bad pair.

repoRoot = fileparts(mfilename('fullpath'));
addpath(fullfile(repoRoot, 'config'));
addpath(fullfile(repoRoot, 'src'));

cfg = default_config(repoRoot);
if nargin == 0 || strlength(string(captureMatPath)) == 0
    captureMatPath = getDefaultCaptureFiles(cfg.paths.rawIqRoot);
end

captureMatPaths = normalizeCaptureInput(captureMatPath);
analysisResults = repmat(emptyResultStruct(), numel(captureMatPaths), 1);

for idx = 1:numel(captureMatPaths)
    currentCapturePath = captureMatPaths{idx};
    analysisResults(idx) = analyzeOneCapture(currentCapturePath, cfg);

    fprintf('=== Offline Channel Observation Summary (%d/%d) ===\n', idx, numel(captureMatPaths));
    fprintf('Input file: %s\n', currentCapturePath);
    fprintf('Detected PCI: %d\n', analysisResults(idx).pbchAnalysis.syncGridResult.searchResult.detectedPCI);
    fprintf('Selected SCS: %d kHz\n', analysisResults(idx).pbchAnalysis.syncGridResult.searchResult.selectedSCSkHz);
    fprintf('Estimated CFO: %.2f Hz\n', analysisResults(idx).pbchAnalysis.syncGridResult.cfoResult.estimatedCfoHz);
    fprintf('Residual timing applied: %.3f samples\n', ...
        analysisResults(idx).pbchAnalysis.syncGridResult.phaseRefinementResult.appliedResidualTimingSamples);
    fprintf('PBCH phase slope |before| %.6f -> |after| %.6f rad/subcarrier\n', ...
        analysisResults(idx).pbchAnalysis.syncGridResult.phaseRefinementResult.initialSlopeAbs, ...
        analysisResults(idx).pbchAnalysis.syncGridResult.phaseRefinementResult.refinedSlopeAbs);
    fprintf('Representative surrogate CFR symbol: %d\n', analysisResults(idx).interpResult.selectedSymbolIndex);
    fprintf('Representative surrogate CFR length: %d\n', numel(analysisResults(idx).interpResult.selectedSymbolCSI));
    fprintf('Surrogate CIR FFT length: %d\n', analysisResults(idx).cirResult.fftLength);
    fprintf('Observed partial-band width: %.3f MHz\n', analysisResults(idx).cirResult.effectiveBandwidthHz / 1e6);
    fprintf('Peak surrogate PDP value: %.6e\n', max(analysisResults(idx).cirResult.pdp));
    fprintf('Dominant relative delay bin: %.3f us\n', 1e6 * analysisResults(idx).cirResult.dominantRelativeDelaySeconds);
    fprintf('Processed MAT file: %s\n', analysisResults(idx).exportInfo.processedMatPath);
    fprintf('Diagnostics figure: %s\n\n', analysisResults(idx).exportInfo.figurePath);
end

if numel(analysisResults) == 1
    cirAnalysisResult = analysisResults;
else
    cirAnalysisResult = struct();
    cirAnalysisResult.results = analysisResults;
    cirAnalysisResult.captureFiles = string(captureMatPaths(:));
end
end

function analysisResult = analyzeOneCapture(captureMatPath, cfg)
pbchAnalysis = run3_offline_pbch_dmrs_analysis(captureMatPath);
interpResult = interpolateSparseCSI(pbchAnalysis.pbchResult);
cirResult = csiToCir(interpResult.selectedSymbolCSI, ...
    pbchAnalysis.syncGridResult.gridResult.ofdmInfo.SampleRate, ...
    pbchAnalysis.syncGridResult.searchResult.selectedSCSkHz, cfg);

analysisResult = struct();
analysisResult.pbchAnalysis = pbchAnalysis;
analysisResult.interpResult = interpResult;
analysisResult.cirResult = cirResult;
analysisResult.observationView = buildObservationExport(analysisResult, captureMatPath);
analysisResult.exportInfo = exportProcessedResult(analysisResult, cfg, captureMatPath);
end

function captureMatPaths = normalizeCaptureInput(captureMatPath)
if iscell(captureMatPath)
    captureMatPaths = captureMatPath;
elseif isstring(captureMatPath)
    captureMatPaths = cellstr(captureMatPath(:));
elseif ischar(captureMatPath)
    captureMatPaths = {captureMatPath};
else
    error('run_offline_cir_analysis:InvalidInputType', ...
        'captureMatPath must be a char, string array, or cell array of char.');
end
end

function captureMatPaths = getDefaultCaptureFiles(rawIqRoot)
captureMatPaths = {
    fullfile(rawIqRoot, 'capture_20260330_204030_fc_4758.240MHz_sr_30.72MSps.mat')
    };

for idx = 1:numel(captureMatPaths)
    if ~isfile(captureMatPaths{idx})
        error('run_offline_cir_analysis:DefaultFileMissing', ...
            'Default capture file not found: %s', captureMatPaths{idx});
    end
end

fprintf('Using code-selected representative captures:\n');
for idx = 1:numel(captureMatPaths)
    fprintf('  %d. %s\n', idx, captureMatPaths{idx});
end
end

function result = emptyResultStruct()
result = struct( ...
    'pbchAnalysis', struct(), ...
    'interpResult', struct(), ...
    'cirResult', struct(), ...
    'observationView', struct(), ...
    'exportInfo', struct());
end
