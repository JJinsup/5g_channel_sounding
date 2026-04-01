function overlayResult = run_plot_high_confidence_cir_overlay(batchLogPath)
%RUN_PLOT_HIGH_CONFIDENCE_CIR_OVERLAY Overlay derived partial-band surrogate CIR/PDP for accepted captures.
%   Uses the latest offline batch log by default and keeps only
%   isHighConfidencePass rows.

repoRoot = fileparts(mfilename('fullpath'));
addpath(fullfile(repoRoot, 'config'));
addpath(fullfile(repoRoot, 'src'));

cfg = default_config(repoRoot);
if nargin < 1 || strlength(string(batchLogPath)) == 0
    batchLogPath = findLatestBatchLog(cfg.paths.logsRoot);
end

loaded = load(batchLogPath, 'summaryTable');
if ~isfield(loaded, 'summaryTable')
    error('run_plot_high_confidence_cir_overlay:InvalidBatchLog', ...
        'The batch log does not contain summaryTable: %s', batchLogPath);
end

summaryTable = loaded.summaryTable;
passMask = summaryTable.isHighConfidencePass;
passTable = summaryTable(passMask, :);
if isempty(passTable)
    error('run_plot_high_confidence_cir_overlay:NoPassingFiles', ...
        'No high-confidence files were found in %s.', batchLogPath);
end

numPass = height(passTable);
cirMatrix = [];
pdpDbMatrix = [];
delayAxisUs = [];
labels = strings(numPass, 1);
delayResolutionUs = missing;
halfSpanUs = missing;

for idx = 1:numPass
    processedPath = char(passTable.processedMatFile(idx));
    processed = load(processedPath, 'processedObservation');
    if ~isfield(processed, 'processedObservation')
        error('run_plot_high_confidence_cir_overlay:InvalidProcessedFile', ...
            'Processed file is missing processedObservation: %s', processedPath);
    end

    surrogateResult = processed.processedObservation.notForOverInterpretation.partialBandEffectiveCirPdpSurrogate;
    currentDelayAxisUs = 1e6 * surrogateResult.peakAlignedRelativeDelayAxisSeconds;
    currentCirDb = 20 * log10(surrogateResult.peakAlignedPartialBandEffectiveCirMagnitudeSurrogate ./ ...
        max(surrogateResult.peakAlignedPartialBandEffectiveCirMagnitudeSurrogate + eps) + eps);
    currentPdpDb = 10 * log10(surrogateResult.peakAlignedPartialBandEffectivePdpSurrogate ./ ...
        max(surrogateResult.peakAlignedPartialBandEffectivePdpSurrogate + eps) + eps);

    if isempty(delayAxisUs)
        delayAxisUs = currentDelayAxisUs;
        delayResolutionUs = median(diff(currentDelayAxisUs));
        halfSpanUs = max(abs(currentDelayAxisUs));
        cirMatrix = zeros(numel(delayAxisUs), numPass);
        pdpDbMatrix = zeros(numel(delayAxisUs), numPass);
    elseif numel(currentDelayAxisUs) ~= numel(delayAxisUs) || any(abs(currentDelayAxisUs - delayAxisUs) > max(1e-9, 1e-6 * abs(delayResolutionUs)))
        error('run_plot_high_confidence_cir_overlay:InconsistentPeakCenteredAxis', ...
            'Passing files do not share the same peak-aligned surrogate delay axis.');
    end

    cirMatrix(:, idx) = currentCirDb;
    pdpDbMatrix(:, idx) = currentPdpDb;
    [~, captureBaseName] = fileparts(char(passTable.captureFile(idx)));
    labels(idx) = string(sprintf('%02d:%s', passTable.fileIndex(idx), captureBaseName));
end

meanCirDb = mean(cirMatrix, 2);
meanPdpDb = mean(pdpDbMatrix, 2);

figurePath = fullfile(cfg.paths.figuresRoot, 'high_confidence_partial_band_surrogate_overlay.png');
fig = figure('Visible', cfg.diagnostics.figureVisibility, 'Color', 'w', 'Position', [100 100 1400 900]);
tiledlayout(fig, 2, 1, 'Padding', 'compact', 'TileSpacing', 'compact');

nexttile;
plot(delayAxisUs, cirMatrix, 'LineWidth', 0.8);
hold on;
plot(delayAxisUs, meanCirDb, 'k', 'LineWidth', 2.2);
grid on;
xlabel('Relative Delay (us, peak-aligned surrogate axis)');
ylabel('Normalized derived surrogate magnitude (dB)');
title(sprintf('High-Confidence Partial-Band Effective CIR Surrogate Overlay (%d files)', numPass));

nexttile;
plot(delayAxisUs, pdpDbMatrix, 'LineWidth', 0.8);
hold on;
plot(delayAxisUs, meanPdpDb, 'k', 'LineWidth', 2.2);
grid on;
xlabel('Relative Delay (us, peak-aligned surrogate axis)');
ylabel('Normalized derived surrogate PDP (dB)');
title('High-Confidence Partial-Band Effective PDP Surrogate Overlay');

sgtitle(sprintf('Batch Overlay from %s', char(string(batchLogPath))), 'Interpreter', 'none');
saveas(fig, figurePath);
close(fig);

overlayResult = struct();
overlayResult.batchLogPath = char(string(batchLogPath));
overlayResult.figurePath = figurePath;
overlayResult.passTable = passTable;
overlayResult.peakAlignedSurrogateDelayAxisUs = delayAxisUs;
overlayResult.partialBandEffectiveCirSurrogateMatrixDb = cirMatrix;
overlayResult.partialBandEffectivePdpSurrogateMatrixDb = pdpDbMatrix;
overlayResult.meanPartialBandEffectiveCirSurrogateDb = meanCirDb;
overlayResult.meanPartialBandEffectivePdpSurrogateDb = meanPdpDb;
overlayResult.labels = labels;

fprintf('=== High-Confidence Surrogate CIR Overlay Summary ===\n');
fprintf('Batch log: %s\n', overlayResult.batchLogPath);
fprintf('Passing files: %d\n', numPass);
fprintf('Saved overlay figure: %s\n', figurePath);
disp(passTable(:, {'fileIndex','detectedPCI','selectedSCSkHz','cellSearchMetricDb', ...
    'cellSearchPeakToMedianRatio','dominantSurrogatePdp','dominantRelativeDelayUs','captureFile'}));
end

function batchLogPath = findLatestBatchLog(logsRoot)
listing = dir(fullfile(logsRoot, 'offline_cir_batch_*.mat'));
if isempty(listing)
    error('run_plot_high_confidence_cir_overlay:NoBatchLogs', ...
        'No offline batch logs were found in %s.', logsRoot);
end

[~, latestIdx] = max([listing.datenum]);
batchLogPath = fullfile(listing(latestIdx).folder, listing(latestIdx).name);
end
