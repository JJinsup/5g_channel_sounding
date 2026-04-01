function repeatResult = run1_capture_only_repeat_test(testSpec)
%RUN1_CAPTURE_ONLY_REPEAT_TEST Repeat raw IQ capture under one fixed condition.
%   This avoids inline analysis so the host can focus on capture stability.

repoRoot = fileparts(mfilename('fullpath'));
addpath(fullfile(repoRoot, 'config'));
addpath(fullfile(repoRoot, 'src'));

baseCfg = default_config(repoRoot);
if nargin < 1 || isempty(testSpec)
    testSpec = defaultTestSpec(baseCfg);
end

summaryRows = cell(testSpec.repeats, 1);

fprintf('=== Capture-Only Repeat Test Start ===\n');
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
    row.overflowDetected = missing;
    row.samplesCaptured = missing;
    row.peakMagnitude = missing;
    row.rmsMagnitude = missing;
    row.captureFile = "";
    row.figureFile = "";
    row.errorMessage = "";

    try
        captureResults = run_passive_nr_capture(overrides);
        row.captureSucceeded = true;
        row.overflowDetected = captureResults.capture.metadata.overflowDetected;
        row.samplesCaptured = captureResults.capture.metadata.samplesCaptured;
        row.peakMagnitude = captureResults.diagnostics.timeDomain.peakMagnitude;
        row.rmsMagnitude = captureResults.diagnostics.timeDomain.rmsMagnitude;
        row.captureFile = string(captureResults.capture.outputMatPath);
        row.figureFile = string(captureResults.capture.outputFigurePath);
    catch ME
        row.errorMessage = string(ME.message);
        fprintf('Run %d capture failed: %s\n', repIdx, ME.message);
    end

    summaryRows{repIdx} = row;
end

summaryTable = struct2table([summaryRows{:}]');
outputPath = fullfile(baseCfg.paths.logsRoot, ['capture_only_repeat_' char(datetime('now', 'Format', 'yyyyMMdd_HHmmss')) '.mat']);
if ~isfolder(baseCfg.paths.logsRoot)
    mkdir(baseCfg.paths.logsRoot);
end
save(outputPath, 'summaryTable', 'testSpec', '-v7.3');

repeatResult = struct();
repeatResult.summaryTable = summaryTable;
repeatResult.outputPath = outputPath;
repeatResult.testSpec = testSpec;

fprintf('\n=== Capture-Only Repeat Summary ===\n');
disp(summaryTable(:, {'repeatIndex','captureSucceeded','overflowDetected','samplesCaptured','peakMagnitude','rmsMagnitude','captureFile'}));
fprintf('Saved capture-only summary: %s\n', outputPath);
end

function testSpec = defaultTestSpec(baseCfg)
testSpec = struct();
testSpec.centerFrequencyHz = baseCfg.radio.centerFrequencyHz;
testSpec.gainDb = 35;
testSpec.sampleRate = baseCfg.radio.sampleRate;
% Keep the capture-only repeat test aligned with the longer default
% observation window so SSB-burst-like repetition can be inspected later.
testSpec.durationMs = 160;
testSpec.repeats = 1;
end
