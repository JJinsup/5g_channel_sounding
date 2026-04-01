function repeatResult = run_fixed_condition_repeat_test(testSpec)
%RUN_FIXED_CONDITION_REPEAT_TEST Repeat capture/analysis under one fixed condition.
%   This is useful for checking measurement stability and channel variation
%   over time without changing the capture settings.

repoRoot = fileparts(mfilename('fullpath'));
addpath(fullfile(repoRoot, 'config'));
addpath(fullfile(repoRoot, 'src'));

baseCfg = default_config(repoRoot);
if nargin < 1 || isempty(testSpec)
    testSpec = defaultTestSpec(baseCfg);
end

summaryRows = cell(testSpec.repeats, 1);

fprintf('=== Fixed-Condition Repeat Test Start ===\n');
fprintf('Center frequency: %.3f MHz\n', testSpec.centerFrequencyHz / 1e6);
fprintf('Gain: %.1f dB\n', testSpec.gainDb);
fprintf('Sample rate: %.2f MSps\n', testSpec.sampleRate / 1e6);
fprintf('Duration: %.1f ms\n', testSpec.durationMs);
fprintf('Repeats: %d\n', testSpec.repeats);

for repIdx = 1:testSpec.repeats
    fprintf('\n--- Repeat %d / %d ---\n', repIdx, testSpec.repeats);

    overrides = struct();
    overrides.radio = struct();
    overrides.radio.gain = testSpec.gainDb;
    overrides.radio.centerFrequencyOverrideHz = testSpec.centerFrequencyHz;
    overrides.radio.sampleRate = testSpec.sampleRate;
    overrides.radio.masterClockRate = testSpec.sampleRate;
    overrides.capture = struct();
    overrides.capture.durationMs = testSpec.durationMs;

    row = struct();
    row.repeatIndex = repIdx;
    row.timestamp = string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
    row.centerFrequencyMHz = testSpec.centerFrequencyHz / 1e6;
    row.gainDb = testSpec.gainDb;
    row.sampleRateMsps = testSpec.sampleRate / 1e6;
    row.durationMs = testSpec.durationMs;
    row.captureSucceeded = false;
    row.analysisSucceeded = false;
    row.overflowDetected = missing;
    row.captureFile = "";
    row.detectedPCI = missing;
    row.selectedSCSkHz = missing;
    row.timingOffset = missing;
    row.combinedMetricDb = missing;
    row.combinedPeakToMedianRatio = missing;
    row.combinedScore = missing;
    row.pbchBestSymbolStart = missing;
    row.pbchBestBlockEnergy = missing;
    row.pbchMeanAbsEstimate = missing;
    row.peakPdp = missing;
    row.peakDelayUs = missing;
    row.errorMessage = "";

    try
        captureResults = run_passive_nr_capture(overrides);
        row.captureSucceeded = true;
        row.overflowDetected = captureResults.capture.metadata.overflowDetected;
        row.captureFile = string(captureResults.capture.outputMatPath);

        analysisCfg = default_config(repoRoot, overrides);
        searchResult = runCellSearch(captureResults.capture.iq, analysisCfg, captureResults.capture.metadata);
        syncResult = correctTimingOffset(captureResults.capture.iq, searchResult.timingOffset, analysisCfg);
        gridResult = buildResourceGrid(syncResult.synchronizedWaveform, searchResult.selectedSCSkHz, analysisCfg, captureResults.capture.metadata.sampleRate);
        pbchResult = estimatePBCHDMRSCSI(gridResult, searchResult.detectedPCI, analysisCfg);
        interpResult = interpolateSparseCSI(pbchResult);
        cirResult = csiToCir(interpResult.meanCSI, captureResults.capture.metadata.sampleRate, searchResult.selectedSCSkHz, analysisCfg);

        bestCandidate = searchResult.candidateResults(find([searchResult.candidateResults.combinedScore] == max([searchResult.candidateResults.combinedScore]), 1, 'first'));

        row.analysisSucceeded = true;
        row.detectedPCI = searchResult.detectedPCI;
        row.selectedSCSkHz = searchResult.selectedSCSkHz;
        row.timingOffset = searchResult.timingOffset;
        row.combinedMetricDb = bestCandidate.combinedMetricDb;
        row.combinedPeakToMedianRatio = bestCandidate.combinedPeakToMedianRatio;
        row.combinedScore = bestCandidate.combinedScore;
        row.pbchBestSymbolStart = pbchResult.bestSymbolStart;
        row.pbchBestBlockEnergy = pbchResult.bestBlockEnergy;
        row.pbchMeanAbsEstimate = pbchResult.meanAbsEstimate;
        row.peakPdp = max(cirResult.pdp);
        row.peakDelayUs = 1e6 * cirResult.delayAxisSeconds(find(cirResult.pdp == max(cirResult.pdp), 1, 'first'));
    catch ME
        row.errorMessage = string(ME.message);
        fprintf('Run %d analysis failed: %s\n', repIdx, ME.message);
    end

    summaryRows{repIdx} = row;
end

summaryTable = struct2table([summaryRows{:}]');
outputPath = fullfile(baseCfg.paths.logsRoot, ['fixed_condition_repeat_' char(datetime('now', 'Format', 'yyyyMMdd_HHmmss')) '.mat']);
if ~isfolder(baseCfg.paths.logsRoot)
    mkdir(baseCfg.paths.logsRoot);
end
save(outputPath, 'summaryTable', 'testSpec', '-v7.3');

repeatResult = struct();
repeatResult.summaryTable = summaryTable;
repeatResult.outputPath = outputPath;
repeatResult.testSpec = testSpec;

fprintf('\n=== Fixed-Condition Repeat Summary ===\n');
disp(summaryTable(:, {'repeatIndex','captureSucceeded','analysisSucceeded','overflowDetected','detectedPCI','selectedSCSkHz','combinedMetricDb','combinedPeakToMedianRatio','combinedScore','pbchBestBlockEnergy','peakDelayUs'}));
fprintf('Saved repeat summary: %s\n', outputPath);
end

function testSpec = defaultTestSpec(baseCfg)
testSpec = struct();
testSpec.centerFrequencyHz = baseCfg.radio.centerFrequencyHz;
testSpec.gainDb = 35;
testSpec.sampleRate = baseCfg.radio.sampleRate;
% Use a shorter window than the capture-only test to keep repeated
% capture+analysis cycles manageable while still giving SSB bursts time to
% appear in most runs.
testSpec.durationMs = 40;
testSpec.repeats = 10;
end
