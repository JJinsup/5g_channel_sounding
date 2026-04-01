function processedObservation = buildObservationExport(cirAnalysisResult, captureMatPath)
%BUILDOBSERVATIONEXPORT Build an honest export structure for downstream use.
%   This helper separates directly measured PBCH-DMRS observables from
%   hypothesis metadata and from derived surrogate CFR/CIR products.

arguments
    cirAnalysisResult (1,1) struct
    captureMatPath (1,:) char
end

syncGridResult = cirAnalysisResult.pbchAnalysis.syncGridResult;
searchResult = syncGridResult.searchResult;
pbchResult = cirAnalysisResult.pbchAnalysis.pbchResult;
interpResult = cirAnalysisResult.interpResult;
cirResult = cirAnalysisResult.cirResult;

measuredRefMask = ~isnan(pbchResult.sparseCSI);
bestCandidate = findBestCandidate(searchResult.candidateResults);

processedObservation = struct();
processedObservation.pipelineLabel = 'passive_ota_private_5g_channel_observation';
processedObservation.scientificDescription = ['Passive OTA private-5G channel observation using a semi-guided NR synchronization hypothesis, ' ...
    'PBCH-DMRS hypothesis-conditioned sparse LS channel extraction, interpolated partial-band effective CFR, ' ...
    'and IFFT-derived partial-band effective CIR/PDP surrogate.'];
processedObservation.capture = struct();
processedObservation.capture.sourceRawIqMatPath = captureMatPath;
processedObservation.capture.metadata = syncGridResult.captureMetadata;

processedObservation.hypothesis = struct();
processedObservation.hypothesis.searchMode = searchResult.mode;
processedObservation.hypothesis.searchMethod = searchResult.method;
processedObservation.hypothesis.searchSuccess = searchResult.success;
processedObservation.hypothesis.detectedPciHypothesis = searchResult.detectedPCI;
processedObservation.hypothesis.selectedScsHypothesisKHz = searchResult.selectedSCSkHz;
processedObservation.hypothesis.timingOffsetSamples = searchResult.timingOffset;
processedObservation.hypothesis.cfoEstimateHz = syncGridResult.cfoResult.estimatedCfoHz;
processedObservation.hypothesis.manualResidualTimingSamples = syncGridResult.manualResidualSyncResult.appliedResidualTimingSamples;
processedObservation.hypothesis.pbchPhaseRefinementMethod = syncGridResult.phaseRefinementResult.method;
processedObservation.hypothesis.pbchDmrsSelection = struct( ...
    'localSymbolStart', pbchResult.bestSymbolStart, ...
    'phaseAlignmentMethod', pbchResult.phaseAlignment.method);

processedObservation.qualityMetrics = struct();
processedObservation.qualityMetrics.cellSearchCombinedMetric = searchResult.metric;
processedObservation.qualityMetrics.cellSearchCombinedMetricDb = bestCandidate.combinedMetricDb;
processedObservation.qualityMetrics.cellSearchPeakToMedianRatio = bestCandidate.combinedPeakToMedianRatio;
processedObservation.qualityMetrics.pbchDmrsBlockMeanEnergy = pbchResult.bestBlockEnergy;
processedObservation.qualityMetrics.measuredSparseRefCount = nnz(measuredRefMask);
processedObservation.qualityMetrics.measuredSparseRefRatio = nnz(measuredRefMask) / numel(measuredRefMask);
processedObservation.qualityMetrics.interpolatedSurrogateNanRatio = interpResult.nanRatioAfterInterpolation;

processedObservation.primaryTrustworthyObservables = struct();
processedObservation.primaryTrustworthyObservables.measuredPbchDmrsIndices = pbchResult.dmrsIndices;
processedObservation.primaryTrustworthyObservables.hypothesisConditionedPbchDmrsSymbols = pbchResult.dmrsSymbols;
processedObservation.primaryTrustworthyObservables.receivedPbchDmrsSamples = pbchResult.rxDmrs;
processedObservation.primaryTrustworthyObservables.hypothesisConditionedSparseLsChannelSamples = pbchResult.lsEstimate;
processedObservation.primaryTrustworthyObservables.hypothesisConditionedSparseLsChannelGrid = pbchResult.sparseCSI;
processedObservation.primaryTrustworthyObservables.measuredSparseRefMask = measuredRefMask;

processedObservation.heuristicDerivedObservables = struct();
processedObservation.heuristicDerivedObservables.interpolatedSurrogateCfrGrid = interpResult.interpolatedCSI;
processedObservation.heuristicDerivedObservables.interpolatedSurrogateCfrMagnitude = interpResult.interpolatedMagnitude;
processedObservation.heuristicDerivedObservables.interpolatedSurrogateCfrPhase = interpResult.interpolatedPhase;
processedObservation.heuristicDerivedObservables.representativeSymbolIndex = interpResult.selectedSymbolIndex;
processedObservation.heuristicDerivedObservables.representativeInterpolatedSurrogateCfr = interpResult.selectedSymbolCSI;
processedObservation.heuristicDerivedObservables.phaseAlignedAverageSurrogateCfr = interpResult.alignedAverageCSI;

processedObservation.notForOverInterpretation = struct();
processedObservation.notForOverInterpretation.partialBandEffectiveCirPdpSurrogate = struct();
processedObservation.notForOverInterpretation.partialBandEffectiveCirPdpSurrogate.inputInterpolatedSurrogateCfr = cirResult.csiVector;
processedObservation.notForOverInterpretation.partialBandEffectiveCirPdpSurrogate.partialBandEffectiveCirSurrogate = cirResult.cir;
processedObservation.notForOverInterpretation.partialBandEffectiveCirPdpSurrogate.partialBandEffectiveCirMagnitudeSurrogate = cirResult.cirMagnitude;
processedObservation.notForOverInterpretation.partialBandEffectiveCirPdpSurrogate.partialBandEffectivePdpSurrogate = cirResult.pdp;
processedObservation.notForOverInterpretation.partialBandEffectiveCirPdpSurrogate.relativeIfftDelayAxisSeconds = cirResult.delayAxisSeconds;
processedObservation.notForOverInterpretation.partialBandEffectiveCirPdpSurrogate.centeredRelativeDelayAxisSeconds = cirResult.centeredDelayAxisSeconds;
processedObservation.notForOverInterpretation.partialBandEffectiveCirPdpSurrogate.peakAlignedRelativeDelayAxisSeconds = cirResult.peakCenteredDelayAxisSeconds;
processedObservation.notForOverInterpretation.partialBandEffectiveCirPdpSurrogate.peakAlignedPartialBandEffectiveCirMagnitudeSurrogate = cirResult.peakCenteredCirMagnitude;
processedObservation.notForOverInterpretation.partialBandEffectiveCirPdpSurrogate.peakAlignedPartialBandEffectivePdpSurrogate = cirResult.peakCenteredPdp;
processedObservation.notForOverInterpretation.partialBandEffectiveCirPdpSurrogate.thresholdedPeakAlignedPdpForVisualization = cirResult.thresholdedPeakCenteredPdp;
processedObservation.notForOverInterpretation.partialBandEffectiveCirPdpSurrogate.dominantRelativeDelaySeconds = cirResult.dominantRelativeDelaySeconds;
processedObservation.notForOverInterpretation.partialBandEffectiveCirPdpSurrogate.centeredDominantRelativeDelaySeconds = cirResult.centeredDominantRelativeDelaySeconds;
processedObservation.notForOverInterpretation.partialBandEffectiveCirPdpSurrogate.relativeStrongestBinDelaySeconds = cirResult.strongestTapDelaySeconds;

processedObservation.cautionaryNotes = [ ...
    "Sparse LS channel samples are conditioned on the selected PCI/SCS/PBCH-DMRS hypothesis." ...
    "Interpolated surrogate CFR is a heuristic derived product and should not be interpreted as true full-band CSI." ...
    "IFFT-derived CIR/PDP is a partial-band effective surrogate and should not be interpreted as absolute path delay, ToA, or true physical tap structure." ...
    ];
end

function bestCandidate = findBestCandidate(candidateResults)
if isempty(candidateResults)
    bestCandidate = struct( ...
        'combinedMetricDb', NaN, ...
        'combinedPeakToMedianRatio', NaN);
    return;
end

[~, bestIdx] = max([candidateResults.combinedScore]);
bestCandidate = candidateResults(bestIdx);
end
