function interpResult = interpolateSparseCSI(pbchResult)
%INTERPOLATESPARSECSI Build an interpolated surrogate CFR from sparse PBCH-DMRS LS samples.
%   The interpolation is a heuristic derived product over the 240x4 local
%   SSB block. It should not be interpreted as directly measured dense CSI.

arguments
    pbchResult (1,1) struct
end

sparseCSI = pbchResult.sparseCSI;
[numSubcarriers, numSymbols] = size(sparseCSI);
knownMask = ~isnan(sparseCSI);
if ~any(knownMask, 'all')
    error('interpolateSparseCSI:NoKnownValues', 'Sparse CSI does not contain any valid estimates.');
end

filledMagnitude = nan(numSubcarriers, numSymbols);
filledPhase = nan(numSubcarriers, numSymbols);
symbolHasRefs = false(numSymbols, 1);
symbolMeanRefMagnitude = nan(numSymbols, 1);

for symbolIdx = 1:numSymbols
    mask = knownMask(:, symbolIdx);
    if ~any(mask)
        continue;
    end

    symbolHasRefs(symbolIdx) = true;
    knownSubcarriers = find(mask);
    knownValues = sparseCSI(mask, symbolIdx);
    knownMagnitude = abs(knownValues);
    knownPhase = unwrap(angle(knownValues));
    symbolMeanRefMagnitude(symbolIdx) = mean(knownMagnitude);

    filledMagnitude(:, symbolIdx) = interp1(double(knownSubcarriers), knownMagnitude, ...
        double((1:numSubcarriers).'), 'linear', 'extrap');
    filledPhase(:, symbolIdx) = interp1(double(knownSubcarriers), knownPhase, ...
        double((1:numSubcarriers).'), 'linear', 'extrap');

    filledMagnitude(:, symbolIdx) = clampSymbolEdges(filledMagnitude(:, symbolIdx), knownSubcarriers, knownMagnitude);
    filledPhase(:, symbolIdx) = clampSymbolEdges(filledPhase(:, symbolIdx), knownSubcarriers, knownPhase);
end

availableSymbols = find(symbolHasRefs);
filledCSI = filledMagnitude .* exp(1j * filledPhase);
[~, bestSymbolIdx] = max(symbolMeanRefMagnitude);
selectedSymbolCSI = filledCSI(:, bestSymbolIdx);
selectedSymbolMagnitude = filledMagnitude(:, bestSymbolIdx);
selectedSymbolPhase = filledPhase(:, bestSymbolIdx);

alignedAverageCSI = buildAlignedAverage(filledCSI, availableSymbols);

interpResult = struct();
interpResult.sparseCSI = sparseCSI;
interpResult.interpolatedCSI = filledCSI;
interpResult.interpolatedMagnitude = filledMagnitude;
interpResult.interpolatedPhase = filledPhase;
interpResult.selectedSymbolIndex = bestSymbolIdx;
interpResult.selectedSymbolCSI = selectedSymbolCSI;
interpResult.selectedSymbolMagnitude = selectedSymbolMagnitude;
interpResult.selectedSymbolPhase = selectedSymbolPhase;
interpResult.alignedAverageCSI = alignedAverageCSI;
interpResult.meanCSI = alignedAverageCSI;
interpResult.knownMask = knownMask;
interpResult.symbolHasRefs = symbolHasRefs;
interpResult.symbolMeanRefMagnitude = symbolMeanRefMagnitude;
interpResult.availableSymbolIndices = availableSymbols;
interpResult.validRefReCount = nnz(knownMask);
interpResult.totalReCount = numel(knownMask);
interpResult.validRefReRatio = nnz(knownMask) / numel(knownMask);
interpResult.nanCountBeforeInterpolation = nnz(isnan(sparseCSI));
interpResult.nanRatioBeforeInterpolation = nnz(isnan(sparseCSI)) / numel(sparseCSI);
interpResult.nanCountAfterInterpolation = nnz(isnan(filledCSI));
interpResult.nanRatioAfterInterpolation = nnz(isnan(filledCSI)) / numel(filledCSI);
interpResult.validRefRePerSymbol = sum(knownMask, 1);
interpResult.measuredObservables = struct( ...
    'hypothesisConditionedSparseLsChannelGrid', sparseCSI, ...
    'measuredSparseRefMask', knownMask);
interpResult.derivedSurrogateObservables = struct( ...
    'interpolatedSurrogateCfrGrid', filledCSI, ...
    'representativeSymbolIndex', bestSymbolIdx, ...
    'representativeInterpolatedSurrogateCfr', selectedSymbolCSI, ...
    'phaseAlignedAverageSurrogateCfr', alignedAverageCSI);
end

function filledValues = clampSymbolEdges(filledValues, knownSubcarriers, knownValues)
firstKnown = knownSubcarriers(1);
lastKnown = knownSubcarriers(end);
filledValues(1:firstKnown) = knownValues(1);
filledValues(lastKnown:end) = knownValues(end);
end

function alignedAverageCSI = buildAlignedAverage(filledCSI, availableSymbols)
if isempty(availableSymbols)
    alignedAverageCSI = nan(size(filledCSI, 1), 1);
    return;
end

referenceSymbol = availableSymbols(1);
alignedSymbols = nan(size(filledCSI, 1), numel(availableSymbols));
referenceCSI = filledCSI(:, referenceSymbol);

for idx = 1:numel(availableSymbols)
    symbolIdx = availableSymbols(idx);
    currentCSI = filledCSI(:, symbolIdx);
    commonPhaseOffset = angle(sum(currentCSI .* conj(referenceCSI)));
    alignedSymbols(:, idx) = currentCSI .* exp(-1j * commonPhaseOffset);
end

alignedAverageCSI = mean(alignedSymbols, 2, 'omitnan');
end
