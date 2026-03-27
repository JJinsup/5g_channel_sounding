function refinementResult = estimateResidualTimingFromPbch(pbchResult, scsKHz, sampleRate, cfg)
%ESTIMATERESIDUALTIMINGFROMPBCH Estimate residual timing from PBCH DM-RS phase slope.
%   Fits an unwrapped phase slope versus subcarrier index per DM-RS symbol
%   and converts the median slope into a fractional timing correction.

arguments
    pbchResult (1,1) struct
    scsKHz (1,1) double
    sampleRate (1,1) double
    cfg (1,1) struct
end

[subcarrierIdx, symbolIdx] = ind2sub(size(pbchResult.bestBlock), pbchResult.dmrsIndices);
lsEstimate = pbchResult.lsEstimate(:);
uniqueSymbols = unique(symbolIdx(:)).';
symbolSlopes = nan(numel(uniqueSymbols), 1);
symbolIntercepts = nan(numel(uniqueSymbols), 1);

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
    coeffs = polyfit(xSorted, ySorted, 1);
    symbolSlopes(idx) = coeffs(1);
    symbolIntercepts(idx) = coeffs(2);
end

validSlopeMask = ~isnan(symbolSlopes);
if ~any(validSlopeMask)
    error('estimateResidualTimingFromPbch:NoValidSlopes', ...
        'Unable to estimate residual timing because no valid phase slopes were found.');
end

medianSlopeRadPerSubcarrier = median(symbolSlopes(validSlopeMask));
residualTimingSeconds = -medianSlopeRadPerSubcarrier / (2 * pi * scsKHz * 1e3);
residualTimingSamples = residualTimingSeconds * sampleRate;
clippedResidualTimingSamples = max(-cfg.sync.maxAutoResidualTimingSamples, ...
    min(cfg.sync.maxAutoResidualTimingSamples, residualTimingSamples));

refinementResult = struct();
refinementResult.symbolIndices = uniqueSymbols(:);
refinementResult.symbolSlopesRadPerSubcarrier = symbolSlopes;
refinementResult.symbolInterceptsRad = symbolIntercepts;
refinementResult.medianSlopeRadPerSubcarrier = medianSlopeRadPerSubcarrier;
refinementResult.estimatedResidualTimingSeconds = residualTimingSeconds;
refinementResult.estimatedResidualTimingSamples = residualTimingSamples;
refinementResult.clippedResidualTimingSamples = clippedResidualTimingSamples;
refinementResult.sampleRate = sampleRate;
refinementResult.scsKHz = scsKHz;
refinementResult.method = 'PBCH DM-RS phase slope fit';
end
