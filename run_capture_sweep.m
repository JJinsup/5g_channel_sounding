function sweepResult = run_capture_sweep(sweepSpec)
%RUN_CAPTURE_SWEEP Capture multiple parameter combinations and score them.
%   By default, this sweeps gain, center frequency, and capture duration,
%   then evaluates each capture with the current semi-guided search metric.

repoRoot = fileparts(mfilename('fullpath'));
addpath(fullfile(repoRoot, 'config'));
addpath(fullfile(repoRoot, 'src'));

baseCfg = default_config(repoRoot);
if nargin < 1 || isempty(sweepSpec)
    sweepSpec = defaultSweepSpec(baseCfg);
end

combinations = buildCombinations(sweepSpec);
summaryRows = cell(numel(combinations), 1);

fprintf('=== Capture Sweep Start ===\n');
fprintf('Total runs: %d\n', numel(combinations));

for idx = 1:numel(combinations)
    overrides = combinations{idx};
    fprintf('\n--- Sweep Run %d / %d ---\n', idx, numel(combinations));
    fprintf('Gain %.1f dB | Fc %.3f MHz | Duration %.1f ms\n', ...
        overrides.radio.gain, overrides.radio.centerFrequencyOverrideHz / 1e6, overrides.capture.durationMs);

    captureResults = run_passive_nr_capture(overrides);
    searchCfg = default_config(repoRoot, overrides);
    searchResult = runCellSearch(captureResults.capture.iq, searchCfg, captureResults.capture.metadata);

    bestCandidate = searchResult.candidateResults(find([searchResult.candidateResults.combinedScore] == max([searchResult.candidateResults.combinedScore]), 1, 'first'));

    summaryRows{idx} = struct(...
        'runIndex', idx, ...
        'gainDb', overrides.radio.gain, ...
        'centerFrequencyMHz', overrides.radio.centerFrequencyOverrideHz / 1e6, ...
        'durationMs', overrides.capture.durationMs, ...
        'overflowDetected', captureResults.capture.metadata.overflowDetected, ...
        'captureFile', string(captureResults.capture.outputMatPath), ...
        'success', searchResult.success, ...
        'detectedPCI', searchResult.detectedPCI, ...
        'selectedSCSkHz', searchResult.selectedSCSkHz, ...
        'timingOffset', searchResult.timingOffset, ...
        'combinedMetricDb', bestCandidate.combinedMetricDb, ...
        'combinedPeakToMedianRatio', bestCandidate.combinedPeakToMedianRatio, ...
        'combinedScore', bestCandidate.combinedScore);
end

summaryTable = struct2table([summaryRows{:}]');
summaryTable = sortrows(summaryTable, {'overflowDetected','combinedScore'}, {'ascend','descend'});

outputPath = fullfile(baseCfg.paths.logsRoot, ['capture_sweep_' char(datetime('now', 'Format', 'yyyyMMdd_HHmmss')) '.mat']);
if ~isfolder(baseCfg.paths.logsRoot)
    mkdir(baseCfg.paths.logsRoot);
end
save(outputPath, 'summaryTable', 'sweepSpec', '-v7.3');

sweepResult = struct();
sweepResult.summaryTable = summaryTable;
sweepResult.outputPath = outputPath;
sweepResult.sweepSpec = sweepSpec;

fprintf('\n=== Capture Sweep Summary ===\n');
disp(summaryTable(:, {'runIndex','gainDb','centerFrequencyMHz','durationMs','overflowDetected','detectedPCI','selectedSCSkHz','combinedMetricDb','combinedPeakToMedianRatio','combinedScore'}));
fprintf('Saved sweep summary: %s\n', outputPath);
end

function sweepSpec = defaultSweepSpec(baseCfg)
sweepSpec = struct();
sweepSpec.gainDb = [25 30 35 40];
sweepSpec.centerFrequencyHz = baseCfg.radio.centerFrequencyHz + [-0.5e6 0 0.5e6];
sweepSpec.durationMs = [10 20];
end

function combinations = buildCombinations(sweepSpec)
combinations = {};
idx = 0;
for gainDb = sweepSpec.gainDb
    for centerFrequencyHz = sweepSpec.centerFrequencyHz
        for durationMs = sweepSpec.durationMs
            idx = idx + 1;
            overrides = struct();
            overrides.radio = struct();
            overrides.radio.gain = gainDb;
            overrides.radio.centerFrequencyOverrideHz = centerFrequencyHz;
            overrides.capture = struct();
            overrides.capture.durationMs = durationMs;
            combinations{idx,1} = overrides; %#ok<AGROW>
        end
    end
end
end
