function pbchResult = applyPbchSymbolPhaseAlignment(pbchResult)
%APPLYPBCHSYMBOLPHASEALIGNMENT Remove per-symbol affine phase from PBCH DM-RS CSI.
%   Fits phase = a*k + b on each PBCH DM-RS symbol and derotates both the
%   sparse LS estimates and the corresponding 240x4 SSB block.

arguments
    pbchResult (1,1) struct
end

[subcarrierIdx, symbolIdx] = ind2sub(size(pbchResult.bestBlock), pbchResult.dmrsIndices);
lsEstimate = pbchResult.lsEstimate(:);
uniqueSymbols = unique(symbolIdx(:)).';
symbolFits = repmat(struct( ...
    'symbolIndex', 0, ...
    'slopeBefore', 0, ...
    'offsetBefore', 0, ...
    'slopeAfter', 0, ...
    'offsetAfter', 0), numel(uniqueSymbols), 1);

alignedLsEstimate = lsEstimate;
alignedBestBlock = pbchResult.bestBlock;
subcarrierAxis = (1:size(pbchResult.bestBlock, 1)).';

for idx = 1:numel(uniqueSymbols)
    currentSymbol = uniqueSymbols(idx);
    mask = symbolIdx == currentSymbol;
    if nnz(mask) < 4
        continue;
    end

    x = double(subcarrierIdx(mask));
    y = unwrap(angle(lsEstimate(mask)));
    [xSorted, order] = sort(x);
    ySorted = y(order);
    coeffsBefore = polyfit(xSorted, ySorted, 1);

    symbolCorrection = exp(-1j * (coeffsBefore(1) * subcarrierAxis + coeffsBefore(2)));
    alignedBestBlock(:, currentSymbol) = alignedBestBlock(:, currentSymbol) .* symbolCorrection;
    alignedLsEstimate(mask) = lsEstimate(mask) .* exp(-1j * (coeffsBefore(1) * x + coeffsBefore(2)));

    yAfter = unwrap(angle(alignedLsEstimate(mask)));
    coeffsAfter = polyfit(xSorted, yAfter(order), 1);

    symbolFits(idx).symbolIndex = currentSymbol;
    symbolFits(idx).slopeBefore = coeffsBefore(1);
    symbolFits(idx).offsetBefore = coeffsBefore(2);
    symbolFits(idx).slopeAfter = coeffsAfter(1);
    symbolFits(idx).offsetAfter = coeffsAfter(2);
end

alignedSparseCSI = nan(size(pbchResult.bestBlock));
alignedSparseCSI(pbchResult.dmrsIndices) = alignedLsEstimate;

pbchResult.rawLsEstimate = pbchResult.lsEstimate;
pbchResult.rawSparseCSI = pbchResult.sparseCSI;
pbchResult.rawBestBlock = pbchResult.bestBlock;
pbchResult.lsEstimate = alignedLsEstimate;
pbchResult.sparseCSI = alignedSparseCSI;
pbchResult.bestBlock = alignedBestBlock;
pbchResult.phaseAlignment = struct();
pbchResult.phaseAlignment.symbolFits = symbolFits;
pbchResult.phaseAlignment.meanSlopeAbsBefore = mean(abs([symbolFits.slopeBefore]));
pbchResult.phaseAlignment.meanSlopeAbsAfter = mean(abs([symbolFits.slopeAfter]));
pbchResult.phaseAlignment.method = 'per-symbol affine phase derotation';
end
