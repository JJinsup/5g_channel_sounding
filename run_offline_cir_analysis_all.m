function batchResult = run_offline_cir_analysis_all(rawIqRoot)
%RUN_OFFLINE_CIR_ANALYSIS_ALL Analyze every capture MAT file under rawIqRoot.
%   Uses the same per-file CIR analysis path as run_offline_cir_analysis,
%   then saves batch summaries separately for each capture-duration bucket.

repoRoot = fileparts(mfilename('fullpath'));
addpath(fullfile(repoRoot, 'config'));
addpath(fullfile(repoRoot, 'src'));

cfg = default_config(repoRoot);
if nargin < 1 || strlength(string(rawIqRoot)) == 0
    rawIqRoot = cfg.paths.rawIqRoot;
end

listing = dir(fullfile(rawIqRoot, 'capture_*.mat'));
if isempty(listing)
    error('run_offline_cir_analysis_all:NoCaptureFiles', ...
        'No capture MAT files were found in %s.', rawIqRoot);
end

fprintf('=== Offline CIR Batch Analysis Start ===\n');
fprintf('Input folder: %s\n', rawIqRoot);
fprintf('Files found: %d\n', numel(listing));

summaryRows = cell(numel(listing), 1);
for idx = 1:numel(listing)
    capturePath = fullfile(listing(idx).folder, listing(idx).name);
    fprintf('\n--- File %d / %d ---\n%s\n', idx, numel(listing), capturePath);

    row = emptySummaryRow(idx, capturePath);
    row.durationMs = readCaptureDurationMs(capturePath);
    row.durationBucket = string(getDurationBucketName(double(row.durationMs)));

    try
        cirAnalysisResult = run_offline_cir_analysis(capturePath);
        row = populateSummaryRow(row, cirAnalysisResult);
    catch ME
        row.errorMessage = string(ME.message);
        fprintf('Analysis failed: %s\n', ME.message);
    end

    summaryRows{idx} = row;
end

summaryTable = struct2table([summaryRows{:}]');
outputInfo = saveDurationBucketSummaries(summaryTable, cfg.paths.logsRoot);

batchResult = struct();
batchResult.summaryTable = summaryTable;
batchResult.outputInfo = outputInfo;
batchResult.rawIqRoot = rawIqRoot;

fprintf('\n=== Offline CIR Batch Summary ===\n');
disp(summaryTable(:, {'fileIndex','durationBucket','analysisSucceeded','detectedPCI','selectedSCSkHz', ...
    'timingOffset','cfoEstimateHz','appliedResidualTimingSamples', ...
    'pbchPhaseSlopeAbsBefore','pbchPhaseSlopeAbsAfter', ...
    'cellSearchMetricDb','cellSearchPeakToMedianRatio', ...
    'validRefReCount','validRefReRatio','sparseCsiNanRatio', ...
    'peakPdp','peakDelayUs','wrappedPeakDelayUs', ...
    'isPrimaryPass','isHighConfidencePass','captureFile'}));

fprintf('Saved duration-split batch summaries:\n');
for idx = 1:numel(outputInfo)
    fprintf('  %s -> %s\n', outputInfo(idx).durationBucket, outputInfo(idx).outputPath);
end
end

function row = emptySummaryRow(fileIndex, capturePath)
row = struct();
row.fileIndex = fileIndex;
row.captureFile = string(capturePath);
row.durationMs = missing;
row.durationBucket = "";
row.analysisSucceeded = false;
row.detectedPCI = missing;
row.selectedSCSkHz = missing;
row.timingOffset = missing;
row.cellSearchMetric = missing;
row.cellSearchMetricDb = missing;
row.cellSearchPeakToMedianRatio = missing;
row.cfoEstimateHz = missing;
row.autoResidualTimingSamples = missing;
row.autoResidualTimingSamplesClipped = missing;
row.appliedResidualTimingSamples = missing;
row.pbchPhaseSlopeAbsBefore = missing;
row.pbchPhaseSlopeAbsAfter = missing;
row.pbchPhaseSlopeRadPerSubcarrier = missing;
row.pbchBestSymbolStart = missing;
row.pbchBestBlockEnergy = missing;
row.selectedSymbolIndex = missing;
row.validRefReCount = missing;
row.totalRefBlockReCount = missing;
row.validRefReRatio = missing;
row.sparseCsiNanRatio = missing;
row.interpolatedCsiNanRatio = missing;
row.validRefReCountSym1 = missing;
row.validRefReCountSym2 = missing;
row.validRefReCountSym3 = missing;
row.validRefReCountSym4 = missing;
row.peakPdp = missing;
row.peakDelayUs = missing;
row.wrappedPeakDelayUs = missing;
row.isPrimaryPass = false;
row.isHighConfidencePass = false;
row.processedMatFile = "";
row.figureFile = "";
row.errorMessage = "";
end

function durationMs = readCaptureDurationMs(capturePath)
captureFile = load(capturePath);

if isfield(captureFile, 'metadata') && isstruct(captureFile.metadata) && ...
        isfield(captureFile.metadata, 'requestedDurationMs')
    durationMs = captureFile.metadata.requestedDurationMs;
    return;
end

if isfield(captureFile, 'capture') && isstruct(captureFile.capture) && ...
        isfield(captureFile.capture, 'metadata') && isstruct(captureFile.capture.metadata) && ...
        isfield(captureFile.capture.metadata, 'requestedDurationMs')
    durationMs = captureFile.capture.metadata.requestedDurationMs;
    return;
end

if isfield(captureFile, 'results') && isstruct(captureFile.results)
    if isfield(captureFile.results, 'metadata') && isstruct(captureFile.results.metadata) && ...
            isfield(captureFile.results.metadata, 'requestedDurationMs')
        durationMs = captureFile.results.metadata.requestedDurationMs;
        return;
    end

    if isfield(captureFile.results, 'capture') && isstruct(captureFile.results.capture) && ...
            isfield(captureFile.results.capture, 'metadata') && isstruct(captureFile.results.capture.metadata) && ...
            isfield(captureFile.results.capture.metadata, 'requestedDurationMs')
        durationMs = captureFile.results.capture.metadata.requestedDurationMs;
        return;
    end
end

fileName = string(capturePath);
if contains(fileName, "10ms")
    durationMs = 10;
    return;
end
if contains(fileName, "15ms")
    durationMs = 15;
    return;
end

error('run_offline_cir_analysis_all:MissingDurationMetadata', ...
    ['Could not infer capture duration for %s. Checked metadata.requestedDurationMs, ' ...
     'capture.metadata.requestedDurationMs, results.metadata.requestedDurationMs, ' ...
     'results.capture.metadata.requestedDurationMs, and filename fallbacks.'], ...
    capturePath);
end

function row = populateSummaryRow(row, cirAnalysisResult)
searchResult = cirAnalysisResult.pbchAnalysis.syncGridResult.searchResult;
phaseRefinement = cirAnalysisResult.pbchAnalysis.syncGridResult.phaseRefinementResult;
pbchResult = cirAnalysisResult.pbchAnalysis.pbchResult;
interpResult = cirAnalysisResult.interpResult;
cirResult = cirAnalysisResult.cirResult;

row.analysisSucceeded = true;
row.detectedPCI = searchResult.detectedPCI;
row.selectedSCSkHz = searchResult.selectedSCSkHz;
row.timingOffset = searchResult.timingOffset;
row.cellSearchMetric = searchResult.metric;
bestCandidate = searchResult.candidateResults( ...
    find([searchResult.candidateResults.combinedScore] == ...
    max([searchResult.candidateResults.combinedScore]), 1, 'first'));
row.cellSearchMetricDb = bestCandidate.combinedMetricDb;
row.cellSearchPeakToMedianRatio = bestCandidate.combinedPeakToMedianRatio;
row.cfoEstimateHz = cirAnalysisResult.pbchAnalysis.syncGridResult.cfoResult.estimatedCfoHz;
row.autoResidualTimingSamples = phaseRefinement.estimatedResidualTimingSamples;
row.autoResidualTimingSamplesClipped = phaseRefinement.clippedResidualTimingSamples;
row.appliedResidualTimingSamples = phaseRefinement.appliedResidualTimingSamples;
row.pbchPhaseSlopeAbsBefore = phaseRefinement.initialSlopeAbs;
row.pbchPhaseSlopeAbsAfter = phaseRefinement.refinedSlopeAbs;
row.pbchPhaseSlopeRadPerSubcarrier = phaseRefinement.medianSlopeRadPerSubcarrier;
row.pbchBestSymbolStart = pbchResult.bestSymbolStart;
row.pbchBestBlockEnergy = pbchResult.bestBlockEnergy;
row.selectedSymbolIndex = interpResult.selectedSymbolIndex;
row.validRefReCount = pbchResult.validRefReCount;
row.totalRefBlockReCount = pbchResult.totalBlockReCount;
row.validRefReRatio = pbchResult.validRefReRatio;
row.sparseCsiNanRatio = interpResult.nanRatioBeforeInterpolation;
row.interpolatedCsiNanRatio = interpResult.nanRatioAfterInterpolation;
validPerSymbol = interpResult.validRefRePerSymbol;
row.validRefReCountSym1 = validPerSymbol(1);
row.validRefReCountSym2 = validPerSymbol(2);
row.validRefReCountSym3 = validPerSymbol(3);
row.validRefReCountSym4 = validPerSymbol(4);
row.peakPdp = max(cirResult.pdp);
row.peakDelayUs = 1e6 * cirResult.peakDelaySeconds;
row.wrappedPeakDelayUs = 1e6 * cirResult.centeredPeakDelaySeconds;
row.isPrimaryPass = row.detectedPCI == 1003 && row.selectedSCSkHz == 30;
row.isHighConfidencePass = row.isPrimaryPass && ...
    row.cellSearchMetricDb > -25 && row.cellSearchPeakToMedianRatio > 40;
row.processedMatFile = string(cirAnalysisResult.exportInfo.processedMatPath);
row.figureFile = string(cirAnalysisResult.exportInfo.figurePath);
end

function outputInfo = saveDurationBucketSummaries(summaryTable, logsRoot)
durationBuckets = unique(summaryTable.durationBucket);
durationBuckets = durationBuckets(durationBuckets ~= "");
outputInfo = repmat(struct('durationBucket', "", 'outputPath', ""), numel(durationBuckets), 1);

for idx = 1:numel(durationBuckets)
    bucket = durationBuckets(idx);
    bucketMask = summaryTable.durationBucket == bucket;
    bucketSummaryTable = summaryTable(bucketMask, :);
    bucketLogRoot = fullfile(logsRoot, char(bucket));
    if ~isfolder(bucketLogRoot)
        mkdir(bucketLogRoot);
    end

    outputPath = fullfile(bucketLogRoot, ...
        ['offline_cir_batch_' char(bucket) '_' char(datetime('now', 'Format', 'yyyyMMdd_HHmmss')) '.mat']);
    save(outputPath, 'bucketSummaryTable', '-v7.3');

    outputInfo(idx).durationBucket = bucket;
    outputInfo(idx).outputPath = string(outputPath);
end
end
