function repeatabilityResult = run_frequency_repeatability_test(testSpec)
%RUN_FREQUENCY_REPEATABILITY_TEST Repeat captures over a narrow center-frequency sweep.
%   Keeps gain fixed and evaluates which tuning point most consistently
%   produces the same detected PCI/SCS and the strongest stable score.

repoRoot = fileparts(mfilename('fullpath'));
addpath(fullfile(repoRoot, 'config'));
addpath(fullfile(repoRoot, 'src'));

baseCfg = default_config(repoRoot);
if nargin < 1 || isempty(testSpec)
    testSpec = defaultTestSpec(baseCfg);
end

numRuns = numel(testSpec.centerFrequencyHz) * testSpec.repeats;
summaryRows = cell(numRuns, 1);
rowIdx = 0;

fprintf('=== Frequency Repeatability Test Start ===\n');
fprintf('Gain: %.1f dB\n', testSpec.gainDb);
fprintf('Duration: %.1f ms\n', testSpec.durationMs);
fprintf('Repeats per frequency: %d\n', testSpec.repeats);

for centerFrequencyHz = testSpec.centerFrequencyHz
    for repIdx = 1:testSpec.repeats
        rowIdx = rowIdx + 1;
        fprintf('\n--- Fc %.3f MHz | Repeat %d / %d ---\n', centerFrequencyHz / 1e6, repIdx, testSpec.repeats);

        overrides = struct();
        overrides.radio = struct();
        overrides.radio.gain = testSpec.gainDb;
        overrides.radio.centerFrequencyOverrideHz = centerFrequencyHz;
        overrides.capture = struct();
        overrides.capture.durationMs = testSpec.durationMs;

        captureResults = run_passive_nr_capture(overrides);
        analysisCfg = default_config(repoRoot, overrides);
        searchResult = runCellSearch(captureResults.capture.iq, analysisCfg, captureResults.capture.metadata);
        syncResult = correctTimingOffset(captureResults.capture.iq, searchResult.timingOffset, analysisCfg);
        gridResult = buildResourceGrid(syncResult.synchronizedWaveform, searchResult.selectedSCSkHz, analysisCfg, captureResults.capture.metadata.sampleRate);
        pbchResult = estimatePBCHDMRSCSI(gridResult, searchResult.detectedPCI, analysisCfg);

        bestCandidate = searchResult.candidateResults(find([searchResult.candidateResults.combinedScore] == max([searchResult.candidateResults.combinedScore]), 1, 'first'));

        summaryRows{rowIdx} = struct(...
            'runIndex', rowIdx, ...
            'centerFrequencyMHz', centerFrequencyHz / 1e6, ...
            'repeatIndex', repIdx, ...
            'gainDb', testSpec.gainDb, ...
            'durationMs', testSpec.durationMs, ...
            'overflowDetected', captureResults.capture.metadata.overflowDetected, ...
            'captureFile', string(captureResults.capture.outputMatPath), ...
            'detectedPCI', searchResult.detectedPCI, ...
            'selectedSCSkHz', searchResult.selectedSCSkHz, ...
            'timingOffset', searchResult.timingOffset, ...
            'combinedMetricDb', bestCandidate.combinedMetricDb, ...
            'combinedPeakToMedianRatio', bestCandidate.combinedPeakToMedianRatio, ...
            'combinedScore', bestCandidate.combinedScore, ...
            'pbchBestSymbolStart', pbchResult.bestSymbolStart, ...
            'pbchBestBlockEnergy', pbchResult.bestBlockEnergy);
    end
end

summaryTable = struct2table([summaryRows{:}]');
outputPath = fullfile(baseCfg.paths.logsRoot, ['frequency_repeatability_' char(datetime('now', 'Format', 'yyyyMMdd_HHmmss')) '.mat']);
if ~isfolder(baseCfg.paths.logsRoot)
    mkdir(baseCfg.paths.logsRoot);
end
save(outputPath, 'summaryTable', 'testSpec', '-v7.3');

repeatabilityResult = struct();
repeatabilityResult.summaryTable = summaryTable;
repeatabilityResult.outputPath = outputPath;
repeatabilityResult.testSpec = testSpec;

fprintf('\n=== Frequency Repeatability Summary ===\n');
disp(summaryTable(:, {'runIndex','centerFrequencyMHz','repeatIndex','overflowDetected','detectedPCI','selectedSCSkHz','combinedMetricDb','combinedPeakToMedianRatio','combinedScore','pbchBestBlockEnergy'}));
fprintf('Saved repeatability summary: %s\n', outputPath);
end

function testSpec = defaultTestSpec(baseCfg)
testSpec = struct();
testSpec.gainDb = 35;
testSpec.centerFrequencyHz = baseCfg.radio.centerFrequencyHz + [-0.5e6 -0.25e6 0 0.25e6 0.5e6];
% Keep enough duration to observe burst-like structure while sweeping
% frequency without making the sweep prohibitively slow.
testSpec.durationMs = 40;
testSpec.repeats = 3;
end
