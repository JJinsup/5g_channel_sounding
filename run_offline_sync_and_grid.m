function syncGridResult = run_offline_sync_and_grid(captureMatPath)
%RUN_OFFLINE_SYNC_AND_GRID Synchronize a saved capture and build a resource grid.
%   Uses the current semi-guided search result, then applies timing
%   correction and OFDM demodulation with the selected SCS.

repoRoot = fileparts(mfilename('fullpath'));
addpath(fullfile(repoRoot, 'config'));
addpath(fullfile(repoRoot, 'src'));

cfg = default_config(repoRoot);

if nargin == 0 || strlength(string(captureMatPath)) == 0
    captureMatPath = findLatestCaptureFile(cfg.paths.rawIqRoot);
end

loaded = load(captureMatPath, 'results');
if ~isfield(loaded, 'results') || ~isfield(loaded.results, 'capture')
    error('run_offline_sync_and_grid:InvalidCaptureFile', 'The MAT file does not contain the expected results.capture structure.');
end

capture = loaded.results.capture;
searchResult = runCellSearch(capture.iq, cfg, capture.metadata);
syncResult = correctTimingOffset(capture.iq, searchResult.timingOffset, cfg);
cfoResult = struct('estimatedCfoHz', 0, ...
    'correctedWaveform', syncResult.synchronizedWaveform, ...
    'numSymbolsUsed', 0, ...
    'method', 'disabled');
if cfg.sync.enableCfoCorrection
    cfoResult = correctCFO(syncResult.synchronizedWaveform, searchResult.selectedSCSkHz, cfg, capture.metadata.sampleRate);
end
manualResidualSyncResult = applyResidualSyncCorrection( ...
    cfoResult.correctedWaveform, capture.metadata.sampleRate, cfg.sync.residualCfoHz, cfg.sync.residualTimingSamples);
initialGridResult = buildResourceGrid(manualResidualSyncResult.correctedWaveform, searchResult.selectedSCSkHz, cfg, capture.metadata.sampleRate);

phaseRefinementResult = struct( ...
    'symbolIndices', [], ...
    'symbolSlopesRadPerSubcarrier', [], ...
    'symbolInterceptsRad', [], ...
    'medianSlopeRadPerSubcarrier', 0, ...
    'estimatedResidualTimingSeconds', 0, ...
    'estimatedResidualTimingSamples', 0, ...
    'clippedResidualTimingSamples', 0, ...
    'appliedResidualTimingSamples', 0, ...
    'selectedTimingSign', 0, ...
    'initialSlopeAbs', 0, ...
    'refinedSlopeAbs', 0, ...
    'sampleRate', capture.metadata.sampleRate, ...
    'scsKHz', searchResult.selectedSCSkHz, ...
    'method', 'disabled');
autoResidualSyncResult = struct( ...
    'correctedWaveform', manualResidualSyncResult.correctedWaveform, ...
    'appliedResidualCfoHz', 0, ...
    'appliedResidualTimingSamples', 0, ...
    'method', 'disabled');
gridResult = initialGridResult;
initialPbchResult = [];

if cfg.sync.enablePbchPhaseRefinement
    initialPbchResult = estimatePBCHDMRSCSI(initialGridResult, searchResult.detectedPCI, cfg);
    basePhaseRefinementResult = estimateResidualTimingFromPbch( ...
        initialPbchResult, searchResult.selectedSCSkHz, capture.metadata.sampleRate, cfg);
    initialSlopeAbs = abs(basePhaseRefinementResult.medianSlopeRadPerSubcarrier);

    bestCandidate = struct( ...
        'timingSamples', 0, ...
        'timingSign', 0, ...
        'residualSyncResult', autoResidualSyncResult, ...
        'gridResult', initialGridResult, ...
        'pbchResult', initialPbchResult, ...
        'slopeAbs', initialSlopeAbs);

    for timingSign = cfg.sync.autoResidualTimingSigns
        trialTimingSamples = timingSign * basePhaseRefinementResult.clippedResidualTimingSamples;
        trialResidualSyncResult = applyResidualSyncCorrection( ...
            manualResidualSyncResult.correctedWaveform, capture.metadata.sampleRate, 0, trialTimingSamples);
        trialGridResult = buildResourceGrid(trialResidualSyncResult.correctedWaveform, ...
            searchResult.selectedSCSkHz, cfg, capture.metadata.sampleRate);
        trialPbchResult = estimatePBCHDMRSCSI(trialGridResult, searchResult.detectedPCI, cfg);
        trialPhaseRefinement = estimateResidualTimingFromPbch( ...
            trialPbchResult, searchResult.selectedSCSkHz, capture.metadata.sampleRate, cfg);
        trialSlopeAbs = abs(trialPhaseRefinement.medianSlopeRadPerSubcarrier);

        if trialSlopeAbs < bestCandidate.slopeAbs
            bestCandidate.timingSamples = trialTimingSamples;
            bestCandidate.timingSign = timingSign;
            bestCandidate.residualSyncResult = trialResidualSyncResult;
            bestCandidate.gridResult = trialGridResult;
            bestCandidate.pbchResult = trialPbchResult;
            bestCandidate.slopeAbs = trialSlopeAbs;
        end
    end

    autoResidualSyncResult = bestCandidate.residualSyncResult;
    gridResult = bestCandidate.gridResult;
    phaseRefinementResult = basePhaseRefinementResult;
    phaseRefinementResult.appliedResidualTimingSamples = bestCandidate.timingSamples;
    phaseRefinementResult.selectedTimingSign = bestCandidate.timingSign;
    phaseRefinementResult.initialSlopeAbs = initialSlopeAbs;
    phaseRefinementResult.refinedSlopeAbs = bestCandidate.slopeAbs;
end

syncGridResult = struct();
syncGridResult.captureFile = captureMatPath;
syncGridResult.captureMetadata = capture.metadata;
syncGridResult.searchResult = searchResult;
syncGridResult.syncResult = syncResult;
syncGridResult.cfoResult = cfoResult;
syncGridResult.initialPbchResult = [];
if exist('initialPbchResult', 'var')
    syncGridResult.initialPbchResult = initialPbchResult;
end
syncGridResult.manualResidualSyncResult = manualResidualSyncResult;
syncGridResult.phaseRefinementResult = phaseRefinementResult;
syncGridResult.residualSyncResult = autoResidualSyncResult;
syncGridResult.gridResult = gridResult;

fprintf('=== Offline Sync + Grid Summary ===\n');
fprintf('Input file: %s\n', captureMatPath);
fprintf('Detected PCI: %d\n', searchResult.detectedPCI);
fprintf('Selected SCS: %d kHz\n', searchResult.selectedSCSkHz);
fprintf('Timing offset: %d samples\n', searchResult.timingOffset);
fprintf('Estimated CFO: %.2f Hz\n', cfoResult.estimatedCfoHz);
fprintf('Manual residual CFO applied: %.2f Hz\n', manualResidualSyncResult.appliedResidualCfoHz);
fprintf('Manual residual timing applied: %.3f samples\n', manualResidualSyncResult.appliedResidualTimingSamples);
fprintf('Auto residual timing estimate: %.3f samples (clipped to %.3f)\n', ...
    phaseRefinementResult.estimatedResidualTimingSamples, phaseRefinementResult.clippedResidualTimingSamples);
fprintf('Auto residual timing applied: %.3f samples (sign %d)\n', ...
    phaseRefinementResult.appliedResidualTimingSamples, phaseRefinementResult.selectedTimingSign);
fprintf('PBCH phase slope |before| %.6f -> |after| %.6f rad/subcarrier\n', ...
    phaseRefinementResult.initialSlopeAbs, phaseRefinementResult.refinedSlopeAbs);
fprintf('Synchronized samples remaining: %d\n', syncResult.samplesRemaining);
fprintf('Grid size: [%d %d %d]\n', gridResult.gridSize(1), gridResult.gridSize(2), size(gridResult.grid, 3));
fprintf('Nfft: %d\n', gridResult.ofdmInfo.Nfft);
fprintf('Sample rate used: %.2f MSps\n', capture.metadata.sampleRate / 1e6);
end

function captureMatPath = findLatestCaptureFile(rawIqRoot)
listing = dir(fullfile(rawIqRoot, 'capture_*.mat'));
if isempty(listing)
    error('run_offline_sync_and_grid:NoCaptureFiles', 'No capture MAT files were found in %s.', rawIqRoot);
end

[~, latestIdx] = max([listing.datenum]);
captureMatPath = fullfile(listing(latestIdx).folder, listing(latestIdx).name);
end
