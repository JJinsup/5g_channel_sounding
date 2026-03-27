function pbchResult = estimatePBCHDMRSCSI(gridResult, pci, cfg)
%ESTIMATEPBCHDMRSCSI Extract PBCH DM-RS REs and compute sparse LS CSI.
%   The current implementation scans the demodulated grid with a 240x4
%   sliding SSB window and picks the block with the strongest PBCH DM-RS
%   energy for the detected PCI.

arguments
    gridResult (1,1) struct
    pci (1,1) double {mustBeInteger, mustBeNonnegative}
    cfg (1,1) struct
end

grid = gridResult.grid(:,:,1);
[numSubcarriers, numSymbols] = size(grid);

if numSubcarriers < 240 || numSymbols < 4
    error('estimatePBCHDMRSCSI:GridTooSmall', 'Grid must be at least 240-by-4 to evaluate PBCH DM-RS.');
end

dmrsIndices = nrPBCHDMRSIndices(pci);
dmrsSymbols = nrPBCHDMRS(pci, cfg.pbch.dmrsIbarSsb);

bestEnergy = -inf;
bestBlock = [];
bestStartSymbol = [];

for symbolStart = 1:(numSymbols - 3)
    ssbBlock = grid(1:240, symbolStart:(symbolStart + 3));
    rxDmrs = nrExtractResources(dmrsIndices, ssbBlock);
    blockEnergy = mean(abs(rxDmrs) .^ 2);
    if blockEnergy > bestEnergy
        bestEnergy = blockEnergy;
        bestBlock = ssbBlock;
        bestStartSymbol = symbolStart;
    end
end

rxDmrs = nrExtractResources(dmrsIndices, bestBlock);
lsEstimate = rxDmrs ./ dmrsSymbols;

sparseCSI = nan(size(bestBlock));
sparseCSI(dmrsIndices) = lsEstimate;

pbchResult = struct();
pbchResult.pci = pci;
pbchResult.dmrsIndices = dmrsIndices;
pbchResult.dmrsSymbols = dmrsSymbols;
pbchResult.rxDmrs = rxDmrs;
pbchResult.lsEstimate = lsEstimate;
pbchResult.sparseCSI = sparseCSI;
pbchResult.bestBlock = bestBlock;
pbchResult.bestSymbolStart = bestStartSymbol;
pbchResult.bestBlockEnergy = bestEnergy;
pbchResult.meanAbsEstimate = mean(abs(lsEstimate));
pbchResult.maxAbsEstimate = max(abs(lsEstimate));
pbchResult.validRefReCount = numel(lsEstimate);
pbchResult.totalBlockReCount = numel(bestBlock);
pbchResult.validRefReRatio = numel(lsEstimate) / numel(bestBlock);
pbchResult.validRefRePerSymbol = sum(~isnan(sparseCSI), 1);
pbchResult.nanCount = nnz(isnan(sparseCSI));
pbchResult.nanRatio = nnz(isnan(sparseCSI)) / numel(sparseCSI);
end
