function exportInfo = exportProcessedResult(cirAnalysisResult, cfg, captureMatPath)
%EXPORTPROCESSEDRESULT Save the current processed observation outputs.

arguments
    cirAnalysisResult (1,1) struct
    cfg (1,1) struct
    captureMatPath (1,:) char
end

[~, captureBaseName] = fileparts(captureMatPath);
outputPrefix = fullfile(cfg.paths.processedRoot, captureBaseName);
durationBucket = getDurationBucketName(cirAnalysisResult.pbchAnalysis.syncGridResult.captureMetadata.requestedDurationMs);
processedObservation = buildObservationExport(cirAnalysisResult, captureMatPath);

if ~isfolder(cfg.paths.processedRoot)
    mkdir(cfg.paths.processedRoot);
end
if ~isfolder(cfg.paths.figuresRoot)
    mkdir(cfg.paths.figuresRoot);
end

processedMatPath = [outputPrefix '_processed.mat'];
figureRoot = fullfile(cfg.paths.figuresRoot, durationBucket);
if ~isfolder(figureRoot)
    mkdir(figureRoot);
end
figurePrefix = fullfile(figureRoot, captureBaseName);

if cfg.export.saveProcessedMat
    save(processedMatPath, 'processedObservation', '-v7.3');
end

figurePath = '';
if cfg.diagnostics.saveFigures
    figurePath = plotCsiCirDiagnostics(cirAnalysisResult, cfg, figurePrefix);
end

exportInfo = struct();
exportInfo.processedMatPath = processedMatPath;
exportInfo.figurePath = figurePath;
end
