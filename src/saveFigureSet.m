function figureFiles = saveFigureSet(figures, outputDir, filePrefix, format)
%SAVEFIGURESET Save a set of MATLAB figures to disk.
%   FORMAT can be "png", "fig", "pdf", or "both".

if nargin < 4 || strlength(string(format)) == 0
    format = "pdf";
end

figureFiles = strings(0,1);
if isempty(figures)
    return;
end

validMask = false(size(figures));
for idx = 1:numel(figures)
    validMask(idx) = isgraphics(figures(idx),"figure");
end
figures = figures(validMask);
if isempty(figures)
    return;
end

outputDir = string(outputDir);
if ~isfolder(outputDir)
    mkdir(outputDir);
end

format = lower(string(format));
if format == "both"
    formats = ["png" "fig"];
else
    formats = format;
end

filePrefix = sanitizeFileStem(filePrefix);
deleteExistingFigureFiles(outputDir,filePrefix);
if format == "pdf"
    outputFile = fullfile(outputDir,filePrefix + ".pdf");
    for figIdx = 1:numel(figures)
        figure(figures(figIdx));
        drawnow;
        exportgraphics(figures(figIdx),outputFile,"Append",figIdx > 1);
    end
    figureFiles = string(outputFile);
    return;
end

for figIdx = 1:numel(figures)
    for fmtIdx = 1:numel(formats)
        fmt = formats(fmtIdx);
        fileBase = sprintf("%s_%02d",filePrefix,figIdx);
        outputFile = fullfile(outputDir,fileBase + "." + fmt);

        switch fmt
            case "png"
                figure(figures(figIdx));
                drawnow;
                saveas(figures(figIdx),outputFile);
            case "fig"
                savefig(figures(figIdx),outputFile);
            otherwise
                error("saveFigureSet:UnsupportedFormat", ...
                    "Unsupported figure format: %s. Use png, fig, or both.",fmt);
        end

        figureFiles(end+1,1) = string(outputFile); %#ok<AGROW>
    end
end
end

function deleteExistingFigureFiles(outputDir, filePrefix)
prefixes = string(filePrefix);
if prefixes == "figures"
    prefixes = ["figures" "mib_sib1" "csi"];
end

for prefix = prefixes
    for extension = ["png" "fig" "pdf"]
        existingFiles = dir(fullfile(outputDir,prefix + "_*." + extension));
        for idx = 1:numel(existingFiles)
            delete(fullfile(existingFiles(idx).folder,existingFiles(idx).name));
        end
    end
    pdfFile = fullfile(outputDir,prefix + ".pdf");
    if isfile(pdfFile)
        delete(pdfFile);
    end
end
end

function fileStem = sanitizeFileStem(fileStem)
fileStem = char(string(fileStem));
fileStem = regexprep(fileStem,"[^A-Za-z0-9_.-]","_");
if isempty(fileStem)
    fileStem = "figure";
end
end
