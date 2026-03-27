function analysisResult = run_offline_pbch_dmrs_analysis(captureMatPath)
%RUN_OFFLINE_PBCH_DMRS_ANALYSIS Run sync, grid generation, and PBCH DM-RS analysis.

repoRoot = fileparts(mfilename('fullpath'));
addpath(fullfile(repoRoot, 'config'));
addpath(fullfile(repoRoot, 'src'));

cfg = default_config(repoRoot);
if nargin == 0 || strlength(string(captureMatPath)) == 0
    captureMatPath = findLatestCaptureFile(cfg.paths.rawIqRoot);
end

syncGridResult = run_offline_sync_and_grid(captureMatPath);
gridDiagnostics = computeGridDiagnostics(syncGridResult.gridResult.grid);
rawPbchResult = estimatePBCHDMRSCSI(syncGridResult.gridResult, syncGridResult.searchResult.detectedPCI, cfg);
pbchResult = applyPbchSymbolPhaseAlignment(rawPbchResult);

analysisResult = struct();
analysisResult.syncGridResult = syncGridResult;
analysisResult.gridDiagnostics = gridDiagnostics;
analysisResult.pbchResult = pbchResult;
analysisResult.pbchBeforeRefinement = syncGridResult.initialPbchResult;
analysisResult.pbchBeforePhaseAlignment = rawPbchResult;

fprintf('=== Offline PBCH DM-RS Analysis Summary ===\n');
fprintf('Detected PCI: %d\n', syncGridResult.searchResult.detectedPCI);
fprintf('Selected SCS: %d kHz\n', syncGridResult.searchResult.selectedSCSkHz);
fprintf('Best PBCH DM-RS block starts at OFDM symbol: %d\n', pbchResult.bestSymbolStart);
fprintf('Best block mean energy: %.6e\n', pbchResult.bestBlockEnergy);
fprintf('Mean |LS estimate|: %.6f\n', pbchResult.meanAbsEstimate);
fprintf('Max |LS estimate|: %.6f\n', pbchResult.maxAbsEstimate);
fprintf('PBCH phase slope mean |before|: %.6f rad/subcarrier\n', pbchResult.phaseAlignment.meanSlopeAbsBefore);
fprintf('PBCH phase slope mean |after|: %.6f rad/subcarrier\n', pbchResult.phaseAlignment.meanSlopeAbsAfter);
fprintf('Peak grid symbol index: %d\n', gridDiagnostics.peakSymbolIndex);
end

function captureMatPath = findLatestCaptureFile(rawIqRoot)
listing = dir(fullfile(rawIqRoot, 'capture_*.mat'));
if isempty(listing)
    error('run_offline_pbch_dmrs_analysis:NoCaptureFiles', 'No capture MAT files were found in %s.', rawIqRoot);
end

[~, latestIdx] = max([listing.datenum]);
captureMatPath = fullfile(listing(latestIdx).folder, listing(latestIdx).name);
end
