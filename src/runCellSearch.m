function searchResult = runCellSearch(iq, cfg, metadata)
%RUNCELLSEARCH Offline semi-guided cell search using available 5G Toolbox functions.
%   This implementation avoids non-existent helper APIs and instead uses
%   nrPSS, nrSSS, nrTimingEstimate, and OFDM reference generation to rank
%   known PCI candidates across a small SCS search set.

arguments
    iq (:,1) double
    cfg (1,1) struct
    metadata (1,1) struct
end

scsList = [cfg.search.defaultSCSkHz, cfg.search.fallbackSCSkHz];
scsList = unique(scsList, 'stable');

candidateResults = [];
for scs = scsList
    for pci = cfg.search.pciCandidates
        candidate = evaluateCandidate(iq, metadata.sampleRate, scs, pci, cfg.search);
        if isempty(candidateResults)
            candidateResults = candidate;
        else
            candidateResults(end + 1, 1) = candidate; %#ok<AGROW>
        end
    end
end

scores = [candidateResults.combinedScore];
selectionPool = candidateResults;
if ~isempty(cfg.search.forcePCI)
    forcedMask = [candidateResults.pci] == cfg.search.forcePCI;
    if ~any(forcedMask)
        error('runCellSearch:ForcedPCINotFound', ...
            'Forced PCI %d is not present in the candidate list.', cfg.search.forcePCI);
    end
    selectionPool = candidateResults(forcedMask);
end

[~, bestIdx] = max([selectionPool.combinedScore]);
bestCandidate = selectionPool(bestIdx);

searchResult = struct();
if isempty(cfg.search.forcePCI)
    searchResult.mode = 'semi-guided';
else
    searchResult.mode = 'forced-pci';
end
searchResult.success = bestCandidate.success;
searchResult.detectedPCI = bestCandidate.pci;
searchResult.selectedSCSkHz = bestCandidate.scskHz;
searchResult.timingOffset = bestCandidate.combinedTimingOffset;
searchResult.metric = bestCandidate.combinedPeakMetric;
searchResult.candidateResults = candidateResults;
searchResult.summaryTable = struct2table(candidateResults);
searchResult.selectionTable = struct2table(selectionPool);
searchResult.forcedPCI = cfg.search.forcePCI;
searchResult.notes = bestCandidate.notes;
searchResult.method = 'nrPSS + nrSSS + nrTimingEstimate';
end

function candidate = evaluateCandidate(iq, sampleRate, scsKHz, pci, searchCfg)
pssGrid = zeros(240, 4);
pssGrid(nrPSSIndices()) = nrPSS(pci);

sssGrid = zeros(240, 4);
sssGrid(nrSSSIndices()) = nrSSS(pci);

combinedGrid = pssGrid + sssGrid;

[pssOffset, pssMag] = nrTimingEstimate(iq, searchCfg.ssBurstNSizeGrid, scsKHz, searchCfg.initialSlot, pssGrid, 'SampleRate', sampleRate);
[sssOffset, sssMag] = nrTimingEstimate(iq, searchCfg.ssBurstNSizeGrid, scsKHz, searchCfg.initialSlot, sssGrid, 'SampleRate', sampleRate);
[combinedOffset, combinedMag] = nrTimingEstimate(iq, searchCfg.ssBurstNSizeGrid, scsKHz, searchCfg.initialSlot, combinedGrid, 'SampleRate', sampleRate);

pssPeak = max(pssMag(:));
sssPeak = max(sssMag(:));
combinedPeak = max(combinedMag(:));

pssMedian = median(pssMag(:) + eps);
sssMedian = median(sssMag(:) + eps);
combinedMedian = median(combinedMag(:) + eps);

pssRatio = pssPeak / max(pssMedian, eps);
sssRatio = sssPeak / max(sssMedian, eps);
combinedRatio = combinedPeak / max(combinedMedian, eps);
combinedMetricDb = 20 * log10(combinedPeak + eps);

candidate = struct();
candidate.pci = pci;
candidate.scskHz = scsKHz;
candidate.pssTimingOffset = pssOffset;
candidate.sssTimingOffset = sssOffset;
candidate.combinedTimingOffset = combinedOffset;
candidate.pssPeakMetric = pssPeak;
candidate.sssPeakMetric = sssPeak;
candidate.combinedPeakMetric = combinedPeak;
candidate.pssPeakToMedianRatio = pssRatio;
candidate.sssPeakToMedianRatio = sssRatio;
candidate.combinedPeakToMedianRatio = combinedRatio;
candidate.combinedMetricDb = combinedMetricDb;
candidate.combinedScore = combinedPeak * combinedRatio;
candidate.success = combinedRatio >= searchCfg.minPeakToMedianRatio && combinedMetricDb >= searchCfg.minPeakPowerDb;
candidate.notes = sprintf('Combined peak %.2f dB, combined peak/median %.2f, PSS ratio %.2f, SSS ratio %.2f', combinedMetricDb, combinedRatio, pssRatio, sssRatio);
end
