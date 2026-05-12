function figureHandles = plotCsiFigures(csi)
%PLOTCSIFIGURES Plot sparse DM-RS CSI magnitude and phase diagnostics.

figureHandles = gobjects(0,1);
if ~isstruct(csi)
    return;
end

if isfield(csi,"pbchDmrsLs")
    figureHandles(end+1,1) = plotOneCsi(csi.pbchDmrsLs,"PBCH DM-RS CSI");
end
if isfield(csi,"pdschDmrsLs")
    figureHandles(end+1,1) = plotOneCsi(csi.pdschDmrsLs,"SIB1 PDSCH DM-RS CSI");
end
if isfield(csi,"csirsCandidate") && isfield(csi.csirsCandidate,"lsEstimate") && ...
        ~isempty(csi.csirsCandidate.lsEstimate)
    figureHandles(end+1,1) = plotOneCsi(csi.csirsCandidate,"TRS/NZP CSI-RS Candidate CSI");
end
end

function fig = plotOneCsi(csiEntry, figureTitle)
fig = figure("Color","w","Name",figureTitle);
tiledlayout(fig,2,2,"Padding","compact","TileSpacing","compact");

sparseGrid = csiEntry.sparseGrid;
referenceMask = csiEntry.referenceMask;
isCsirsEntry = isfield(csiEntry,"source") && contains(string(csiEntry.source),"CSI-RS");
if isCsirsEntry && isfield(csiEntry,"activeSlots") && ~isempty(csiEntry.activeSlots)
    symbolsPerSlot = 14;
    firstSymbol = csiEntry.activeSlots(1)*symbolsPerSlot + 1;
    lastSymbol = csiEntry.activeSlots(end)*symbolsPerSlot + symbolsPerSlot;
    lastSymbol = min(lastSymbol,size(sparseGrid,2));
    sparseGrid = sparseGrid(:,firstSymbol:lastSymbol,:);
    referenceMask = referenceMask(:,firstSymbol:lastSymbol,:);
end
if ~ismatrix(sparseGrid)
    sparseGrid = sparseGrid(:,:,1);
    referenceMask = referenceMask(:,:,1);
end
lsEstimate = csiEntry.lsEstimate(:);
sourceName = "REF";
if isCsirsEntry
    sourceName = "CSIRS";
elseif isfield(csiEntry,"source") && contains(string(csiEntry.source),"DM-RS")
    sourceName = "DMRS";
end
magDbGrid = 20*log10(abs(sparseGrid) + eps);
phaseGrid = angle(sparseGrid);
magDbGrid(~referenceMask) = NaN;
phaseGrid(~referenceMask) = NaN;

nexttile;
plotSparseImage(magDbGrid,referenceMask);
title("|H_{" + sourceName + "}| (dB)");
xlabel("OFDM symbol");
ylabel("Subcarrier");
cb = colorbar;
cb.Label.String = "dB";

nexttile;
plotSparseImage(phaseGrid,referenceMask);
title("angle(H_{" + sourceName + "})");
xlabel("OFDM symbol");
ylabel("Subcarrier");
cb = colorbar;
cb.Label.String = "rad";

refIndex = 1:numel(lsEstimate);
nexttile;
plot(refIndex,20*log10(abs(lsEstimate) + eps),".-","LineWidth",0.8);
grid on;
title("Magnitude over reference REs");
xlabel("Reference RE index");
ylabel("|H| (dB)");

nexttile;
plot(refIndex,unwrap(angle(lsEstimate)),".-","LineWidth",0.8);
grid on;
title("Unwrapped phase over reference REs");
xlabel("Reference RE index");
ylabel("Phase (rad)");

sgtitle(sprintf("%s | refs: %d",figureTitle,numel(lsEstimate)));
end

function plotSparseImage(values, referenceMask)
imagesc(values,"AlphaData",referenceMask);
axis xy;
set(gca,"Color",[0.94 0.94 0.94]);
end
