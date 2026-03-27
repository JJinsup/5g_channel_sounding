function searchResult = run_offline_cell_search(captureMatPath)
%RUN_OFFLINE_CELL_SEARCH Run semi-guided cell search on a saved capture.
%   searchResult = RUN_OFFLINE_CELL_SEARCH() uses the latest raw IQ MAT file
%   in outputs/raw_iq. You can also pass a specific MAT file path.

repoRoot = fileparts(mfilename('fullpath'));
addpath(fullfile(repoRoot, 'config'));
addpath(fullfile(repoRoot, 'src'));

cfg = default_config(repoRoot);

if nargin == 0 || strlength(string(captureMatPath)) == 0
    captureMatPath = findLatestCaptureFile(cfg.paths.rawIqRoot);
end

loaded = load(captureMatPath, 'results');
if ~isfield(loaded, 'results') || ~isfield(loaded.results, 'capture')
    error('run_offline_cell_search:InvalidCaptureFile', 'The MAT file does not contain the expected results.capture structure.');
end

capture = loaded.results.capture;
searchResult = runCellSearch(capture.iq, cfg, capture.metadata);

fprintf('=== Offline Cell Search Summary ===\n');
fprintf('Input file: %s\n', captureMatPath);
fprintf('Method: %s\n', searchResult.method);
fprintf('Semi-guided success: %s\n', string(searchResult.success));
fprintf('Detected PCI: %d\n', searchResult.detectedPCI);
fprintf('Selected SCS: %d kHz\n', searchResult.selectedSCSkHz);
fprintf('Timing offset: %d samples\n', searchResult.timingOffset);
fprintf('Metric note: %s\n\n', searchResult.notes);

disp(searchResult.summaryTable(:, {'pci','scskHz','combinedTimingOffset','combinedMetricDb','combinedPeakToMedianRatio','success'}));
end

function captureMatPath = findLatestCaptureFile(rawIqRoot)
listing = dir(fullfile(rawIqRoot, 'capture_*.mat'));
if isempty(listing)
    error('run_offline_cell_search:NoCaptureFiles', 'No capture MAT files were found in %s.', rawIqRoot);
end

[~, latestIdx] = max([listing.datenum]);
captureMatPath = fullfile(listing(latestIdx).folder, listing(latestIdx).name);
end
