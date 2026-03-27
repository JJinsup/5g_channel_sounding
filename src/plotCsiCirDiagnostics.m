function figurePath = plotCsiCirDiagnostics(cirAnalysisResult, cfg, outputPrefix)
%PLOTCSICIRDIAGNOSTICS Save simple diagnostics for CSI/CIR/PDP inspection.

arguments
    cirAnalysisResult (1,1) struct
    cfg (1,1) struct
    outputPrefix (1,:) char
end

interpResult = cirAnalysisResult.interpResult;
cirResult = cirAnalysisResult.cirResult;
preprocess = cirResult.preprocess;
pbchBeforeRefinement = [];
if isfield(cirAnalysisResult.pbchAnalysis, 'pbchBeforePhaseAlignment')
    pbchBeforeRefinement = cirAnalysisResult.pbchAnalysis.pbchBeforePhaseAlignment;
elseif isfield(cirAnalysisResult.pbchAnalysis, 'pbchBeforeRefinement')
    pbchBeforeRefinement = cirAnalysisResult.pbchAnalysis.pbchBeforeRefinement;
end

figurePath = [outputPrefix '_csi_cir_diagnostics.png'];
fig = figure('Visible', cfg.diagnostics.figureVisibility, 'Color', 'w', 'Position', [100 100 1500 950]);
tiledlayout(fig, 3, 4, 'Padding', 'compact', 'TileSpacing', 'compact');

knownBySubcarrier = any(interpResult.knownMask, 2);
knownSubcarrierIdx = find(knownBySubcarrier);
selectedCsiKnown = interpResult.selectedSymbolCSI(knownBySubcarrier);

nexttile;
scatter(find(interpResult.knownMask(:)), abs(interpResult.sparseCSI(interpResult.knownMask)), 18, 'filled');
grid on;
xlabel('Reference RE Sample');
ylabel('|H|');
title('Raw Sparse CSI Magnitude');

nexttile;
plotPbchPhasePerSymbol([], cirAnalysisResult.pbchAnalysis.pbchResult);
grid on;
xlabel('PBCH DM-RS Subcarrier');
ylabel('Phase (rad)');
title({'PBCH Phase vs Subcarrier', '(PBCH DM-RS symbols only; post-alignment only)'});

nexttile;
imagesc(abs(interpResult.sparseCSI));
axis xy;
colorbar;
xlabel('OFDM Symbol');
ylabel('Subcarrier');
title('Sparse CSI Magnitude');

nexttile;
interpMagnitudeDisplay = abs(interpResult.interpolatedCSI);
interpMagnitudeDisplay(:, ~interpResult.symbolHasRefs.') = NaN;
imagesc(interpMagnitudeDisplay);
axis xy;
colorbar;
xlabel('OFDM Symbol');
ylabel('Subcarrier');
title(sprintf('Interpolated CSI Magnitude (ref-bearing syms only, selected sym %d)', interpResult.selectedSymbolIndex));

nexttile;
imagesc(interpResult.knownMask);
axis xy;
colorbar;
xlabel('OFDM Symbol');
ylabel('Subcarrier');
title('Valid Reference RE Mask');

nexttile;
plotPbchPhaseOffsetRemoved([], cirAnalysisResult.pbchAnalysis.pbchResult);
grid on;
xlabel('PBCH DM-RS Subcarrier');
ylabel('Phase (rad)');
title({'PBCH Phase Offset-Removed Overlay', '(PBCH DM-RS symbols only; post-alignment only)'});

nexttile;
plot(preprocess.rawMagnitude, 'LineWidth', 1.0);
hold on;
plot(knownSubcarrierIdx, abs(selectedCsiKnown), '.', 'MarkerSize', 10);
plot(preprocess.phaseFlattenedMagnitude, 'LineWidth', 1.0);
plot(find(preprocess.trustedMask), preprocess.phaseFlattenedMagnitude(preprocess.trustedMask), '.', 'MarkerSize', 8);
grid on;
xlabel('Subcarrier');
ylabel('|H|');
title('Selected-Symbol CSI Magnitude');
legend('Raw', 'Known bins', 'Flat', 'Trusted', ...
    'Location', 'northwest', 'Box', 'off');

nexttile;
plotSelectedSymbolPhase(preprocess, knownBySubcarrier);
grid on;
xlabel('Subcarrier');
ylabel('Phase (rad)');
title('Selected-Symbol CSI Phase');

nexttile;
centeredCirDisplay = cirResult.cirCenteredMagnitude ./ max(cirResult.cirCenteredMagnitude + eps);
centeredDelayUs = 1e6 * cirResult.centeredDelayAxisSeconds;
plot(centeredDelayUs, centeredCirDisplay, 'LineWidth', 1.4, 'Color', [0 0.4470 0.7410]);
grid on;
xlabel('Centered Delay (us)');
ylabel('Normalized |h(tau)|');
title('Centered CIR Magnitude');
xlim([-20 20]);
ylim([0 1]);

nexttile;
plot(1e6 * cirResult.peakCenteredDelayAxisSeconds, 10 * log10(cirResult.peakCenteredPdp + eps), 'LineWidth', 1.1);
hold on;
plot(1e6 * cirResult.peakCenteredDelayAxisSeconds, 10 * log10(cirResult.thresholdedPeakCenteredPdp + eps), '--', 'LineWidth', 1.0);
grid on;
xlabel('Relative Delay (us)');
ylabel('PDP (dB)');
title('Peak-Centered Power Delay Profile');
legend('Raw', 'Thresholded', 'Location', 'northeast', 'Box', 'off');

nexttile;
relativeDelayNs = 1e9 * cirResult.causalDelayAxisSeconds;
relativeCirDisplay = cirResult.causalCirNormalized ./ max(cirResult.causalCirNormalized + eps);
area(relativeDelayNs, relativeCirDisplay, ...
    'FaceColor', [0.3010 0.7450 0.9330], ...
    'FaceAlpha', 0.35, ...
    'EdgeColor', [0 0.4470 0.7410], ...
    'LineWidth', 1.2);
hold on;
grid on;
xlabel('Delay From First Tap (ns)');
ylabel('Normalized Amplitude');
title(sprintf('Relative CIR View (strongest = %.2f ns relative)', 1e9 * cirResult.strongestTapDelaySeconds));
xlim([0 2e4]);
xticks(0:0.5e4:2e4);
ax = gca;
ax.XAxis.Exponent = 4;
ylim([0 1]);

nexttile;
plot(centeredDelayUs, 20 * log10(centeredCirDisplay + eps), 'LineWidth', 1.2, 'Color', [0.8500 0.3250 0.0980]);
grid on;
xlabel('Centered Delay (us)');
ylabel('Magnitude (dB)');
title('Centered CIR Magnitude (dB)');
xlim([-20 20]);
ylim([-60 0]);

sgtitle('CSI/CIR Diagnostics');
saveas(fig, figurePath);
close(fig);
end

function plotSparsePhase(sparseCSI, knownMask)
phaseValues = angle(sparseCSI(knownMask));
plot(1:numel(phaseValues), unwrap(phaseValues), '.-', 'LineWidth', 0.9, 'MarkerSize', 8);
end

function plotPbchPhasePerSymbol(pbchBeforeRefinement, pbchAfterRefinement)
afterData = getPbchPhaseBySymbol(pbchAfterRefinement);
beforeData = [];
if ~isempty(pbchBeforeRefinement)
    beforeData = getPbchPhaseBySymbol(pbchBeforeRefinement);
end

hold on;
colors = lines(numel(afterData));
legendEntries = strings(0, 1);
legendHandles = gobjects(0, 1);

for idx = 1:numel(afterData)
    hAfter = plot(afterData(idx).subcarrierIdx, afterData(idx).phase, '.-', ...
        'Color', colors(idx, :), 'LineWidth', 1.1, 'MarkerSize', 7);
    legendHandles(end + 1) = hAfter; %#ok<AGROW>
    legendEntries(end + 1) = sprintf('S%d', afterData(idx).symbolIndex); %#ok<AGROW>
end

if ~isempty(legendHandles)
    legend(legendHandles, cellstr(legendEntries), ...
        'Location', 'northeast', 'Box', 'off');
end
end

function plotPbchPhaseOffsetRemoved(pbchBeforeRefinement, pbchAfterRefinement)
afterData = getPbchPhaseBySymbol(pbchAfterRefinement);
beforeData = [];
if ~isempty(pbchBeforeRefinement)
    beforeData = getPbchPhaseBySymbol(pbchBeforeRefinement);
end

hold on;
colors = lines(numel(afterData));
legendEntries = strings(0, 1);
legendHandles = gobjects(0, 1);

for idx = 1:numel(afterData)
    afterPhase = afterData(idx).phase - median(afterData(idx).phase);
    hAfter = plot(afterData(idx).subcarrierIdx, afterPhase, '.-', ...
        'Color', colors(idx, :), 'LineWidth', 1.1, 'MarkerSize', 7);
    legendHandles(end + 1) = hAfter; %#ok<AGROW>
    legendEntries(end + 1) = sprintf('S%d', afterData(idx).symbolIndex); %#ok<AGROW>
end

if ~isempty(legendHandles)
    legend(legendHandles, cellstr(legendEntries), ...
        'Location', 'northeast', 'Box', 'off');
end
end

function symbolData = getPbchPhaseBySymbol(pbchResult)
[subcarrierIdx, symbolIdx] = ind2sub(size(pbchResult.bestBlock), pbchResult.dmrsIndices);
lsEstimate = pbchResult.lsEstimate(:);
uniqueSymbols = unique(symbolIdx(:)).';
symbolData = repmat(struct('symbolIndex', 0, 'subcarrierIdx', [], 'phase', []), numel(uniqueSymbols), 1);

for idx = 1:numel(uniqueSymbols)
    currentSymbol = uniqueSymbols(idx);
    mask = symbolIdx == currentSymbol;
    x = double(subcarrierIdx(mask));
    y = unwrap(angle(lsEstimate(mask)));
    [xSorted, order] = sort(x);
    symbolData(idx).symbolIndex = currentSymbol;
    symbolData(idx).subcarrierIdx = xSorted;
    symbolData(idx).phase = y(order);
end

symbolData = sortSymbolDataForLegend(symbolData);
end

function sortedData = sortSymbolDataForLegend(symbolData)
if isempty(symbolData)
    sortedData = symbolData;
    return;
end

[~, order] = sort([symbolData.symbolIndex]);
sortedData = symbolData(order);
end

function plotMeanCsiPhase(meanCSI, knownBySubcarrier)
subcarrierIdx = (1:numel(meanCSI)).';
rawPhase = angle(meanCSI);
unwrapPhase = unwrap(rawPhase);

plot(subcarrierIdx, rawPhase, 'Color', [0.7 0.7 0.7], 'LineWidth', 0.8);
hold on;
plot(subcarrierIdx, unwrapPhase, 'LineWidth', 1.1);

knownIdx = find(knownBySubcarrier);
if ~isempty(knownIdx)
    plot(knownIdx, unwrapPhase(knownBySubcarrier), '.', 'MarkerSize', 11);
end

legend('Raw angle', 'Unwrapped angle', 'Known-support bins', 'Location', 'best');
end

function plotSelectedSymbolPhase(preprocess, knownBySubcarrier)
subcarrierIdx = (1:numel(preprocess.rawPhase)).';
plot(subcarrierIdx, preprocess.rawPhase, 'Color', [0.7 0.7 0.7], 'LineWidth', 0.8);
hold on;
plot(subcarrierIdx, preprocess.phaseFlattenedPhase, 'LineWidth', 1.1);

trustedIdx = find(preprocess.trustedMask);
if ~isempty(trustedIdx)
    plot(trustedIdx, preprocess.phaseFlattenedPhase(preprocess.trustedMask), '.', 'MarkerSize', 10);
end

knownIdx = find(knownBySubcarrier);
if ~isempty(knownIdx)
    plot(knownIdx, preprocess.rawPhase(knownBySubcarrier), '.', 'MarkerSize', 9);
end

legend('Raw', 'Flat', 'Trusted', 'Known bins', ...
    'Location', 'northwest', 'Box', 'off');
end
