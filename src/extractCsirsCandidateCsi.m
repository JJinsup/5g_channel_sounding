function candidate = extractCsirsCandidateCsi(rxGrid,ncellid,scsCommon,initialSystemInfo)
%EXTRACTCSIRSCANDIDATECSI Extract hypothesis-based TRS/NZP CSI-RS LS CSI.
%   Scans unresolved row-1 CSI-RS candidate parameters, selects the strongest
%   candidate, then stores sparse complex LS channel estimates H = Y / X.
%   Candidate defaults follow docs/trs_nzp_csirs_candidate.md.

candidate = struct();
candidate.source = "TRS/NZP CSI-RS candidate";
candidate.description = "Hypothesis-based sparse LS CSI from candidate NZP CSI-RS/TRS REs: H = Y_CSIRS / X_CSIRS.";
candidate.status = "started";
candidate.error = "";
candidate.validRefReCount = 0;

try
    symbolsPerSlot = 14;
    numRxSymbols = size(rxGrid,2);
    numSlots = floor(numRxSymbols/symbolsPerSlot);
    numRxAntennas = size(rxGrid,3);
    visibleNSizeGrid = floor(size(rxGrid,1)/12);

    if numSlots == 0 || visibleNSizeGrid == 0
        candidate.status = "no_grid";
        return;
    end

    rxGrid = rxGrid(1:visibleNSizeGrid*12,1:numSlots*symbolsPerSlot,:);
    powerOffsetDb = 6;
    scanResults = scanCsirsRow1Candidates(rxGrid,ncellid,scsCommon, ...
        initialSystemInfo.NFrame,visibleNSizeGrid,powerOffsetDb);
    [slotOffset,subcarrierLocation,selection] = selectCsirsCandidate(scanResults);
    [carrier,csirs,assumptions] = buildCsirsCandidateConfig(ncellid,scsCommon, ...
        initialSystemInfo.NFrame,visibleNSizeGrid,slotOffset,subcarrierLocation,powerOffsetDb);

    candidate.assumptions = assumptions;
    candidate.carrier = carrier;
    candidate.csirs = csirs;
    candidate.powerOffsetDb = assumptions.powerOffsetDb;
    candidate.cdmLengths = cdmLengthsFromCsirs(csirs);
    candidate.visibleGridSize = size(rxGrid);
    candidate.visibleNSizeGrid = visibleNSizeGrid;
    candidate.visibleNumSlots = numSlots;
    candidate.note = "CSI-RS resource mapping is applied to the current visible OFDM grid, not confirmed full 100 MHz carrier mapping.";
    candidate.scanResults = scanResults;
    candidate.selection = selection;

    sparseGrid = nan(size(rxGrid),"like",rxGrid);
    referenceMask = false(size(rxGrid));
    txSymbolsAll = zeros(0,1,"like",rxGrid);
    rxSymbolsAll = zeros(0,numRxAntennas,"like",rxGrid);
    lsEstimateAll = zeros(0,numRxAntennas,"like",rxGrid);
    referenceSubscripts = zeros(0,4);
    activeSlots = zeros(0,1);
    skippedSlots = struct("slotIndex",{}, ...
                          "reason",{}, ...
                          "meanRxPower",{});
    slotResults = struct("slotIndex",{}, ...
                         "absoluteSlot",{}, ...
                         "numReferenceRE",{}, ...
                         "meanAbsEstimate",{}, ...
                         "noiseVariance",{}, ...
                         "channelEstimateInfo",{});

    slotsPerFrame = carrier.SlotsPerFrame;
    for slotIdx = 0:numSlots-1
        carrier.NSlot = slotIdx;
        csirsIndices = nrCSIRSIndices(carrier,csirs);
        csirsSymbols = nrCSIRS(carrier,csirs) * db2mag(candidate.powerOffsetDb);
        if isempty(csirsIndices)
            continue;
        end

        slotSymbols = slotIdx*symbolsPerSlot + (1:symbolsPerSlot);
        slotGrid = rxGrid(:,slotSymbols,:);
        csirsRx = nrExtractResources(csirsIndices,slotGrid);
        slotRxPower = mean(abs(csirsRx).^2,"all");
        if ~any(abs(csirsRx) > 0,"all")
            skippedIdx = numel(skippedSlots) + 1;
            skippedSlots(skippedIdx).slotIndex = slotIdx;
            skippedSlots(skippedIdx).reason = "zero_padded_or_empty_grid";
            skippedSlots(skippedIdx).meanRxPower = slotRxPower;
            continue;
        end
        csirsLsEstimate = csirsRx ./ csirsSymbols;

        [~,noiseVariance,channelEstimateInfo] = nrChannelEstimate( ...
            carrier,slotGrid,csirsIndices,csirsSymbols,"CDMLengths",candidate.cdmLengths);

        csirsSubscripts = double(nrCSIRSIndices(carrier,csirs,"IndexStyle","subscript"));
        globalSymbols = csirsSubscripts(:,2) + slotIdx*symbolsPerSlot;
        for rxAntenna = 1:numRxAntennas
            globalIndices = sub2ind(size(sparseGrid),csirsSubscripts(:,1), ...
                globalSymbols,repmat(rxAntenna,size(csirsSubscripts,1),1));
            sparseGrid(globalIndices) = csirsLsEstimate(:,rxAntenna);
            referenceMask(globalIndices) = true;
        end

        numSlotRefs = size(csirsSubscripts,1);
        activeSlots(end+1,1) = slotIdx; %#ok<AGROW>
        referenceSubscripts = [referenceSubscripts; ...
            csirsSubscripts(:,1),globalSymbols,csirsSubscripts(:,3), ...
            repmat(slotIdx,numSlotRefs,1)]; %#ok<AGROW>
        txSymbolsAll = [txSymbolsAll; csirsSymbols]; %#ok<AGROW>
        rxSymbolsAll = [rxSymbolsAll; csirsRx]; %#ok<AGROW>
        lsEstimateAll = [lsEstimateAll; csirsLsEstimate]; %#ok<AGROW>

        slotResultIdx = numel(slotResults) + 1;
        slotResults(slotResultIdx).slotIndex = slotIdx;
        slotResults(slotResultIdx).absoluteSlot = initialSystemInfo.NFrame*slotsPerFrame + slotIdx;
        slotResults(slotResultIdx).numReferenceRE = numSlotRefs;
        slotResults(slotResultIdx).meanAbsEstimate = mean(abs(csirsLsEstimate),"all");
        slotResults(slotResultIdx).noiseVariance = noiseVariance;
        slotResults(slotResultIdx).channelEstimateInfo = channelEstimateInfo;
    end

    candidate.activeSlots = activeSlots;
    candidate.skippedSlots = skippedSlots;
    candidate.slotResults = slotResults;
    candidate.referenceSubscripts = referenceSubscripts;
    candidate.txSymbols = txSymbolsAll;
    candidate.rxSymbols = rxSymbolsAll;
    candidate.lsEstimate = lsEstimateAll;
    candidate.sparseGrid = sparseGrid;
    candidate.referenceMask = referenceMask;
    candidate.validRefReCount = numel(lsEstimateAll);

    if isempty(lsEstimateAll)
        candidate.status = "no_candidate_occurrence";
        candidate.meanAbsEstimate = NaN;
        candidate.maxAbsEstimate = NaN;
    else
        candidate.status = "extracted";
        candidate.meanAbsEstimate = mean(abs(lsEstimateAll),"all");
        candidate.maxAbsEstimate = max(abs(lsEstimateAll),[],"all");
    end
catch ME
    candidate.status = "error";
    candidate.error = string(ME.message);
end
end

function scanResults = scanCsirsRow1Candidates(rxGrid,ncellid,scsCommon,nframe,visibleNSizeGrid,powerOffsetDb)
symbolsPerSlot = 14;
numSlots = floor(size(rxGrid,2)/symbolsPerSlot);
scanResults = struct("slotOffset",{}, ...
                     "subcarrierLocation",{}, ...
                     "activeSlots",{}, ...
                     "skippedZeroSlots",{}, ...
                     "validRefReCount",{}, ...
                     "meanRxPower",{}, ...
                     "relativePowerDb",{}, ...
                     "meanAbsLs",{}, ...
                     "score",{}, ...
                     "status",{});
resultIdx = 0;

for slotOffset = 0:39
    for subcarrierLocation = 0:3
        [carrier,csirs] = buildCsirsRow1Config(ncellid,scsCommon,nframe, ...
            visibleNSizeGrid,slotOffset,subcarrierLocation);
        totalRxPower = 0;
        totalGridPower = 0;
        totalAbsLs = 0;
        validRefReCount = 0;
        activeSlots = zeros(0,1);
        skippedZeroSlots = zeros(0,1);

        for slotIdx = 0:numSlots-1
            carrier.NSlot = slotIdx;
            csirsIndices = nrCSIRSIndices(carrier,csirs);
            if isempty(csirsIndices)
                continue;
            end

            slotSymbols = slotIdx*symbolsPerSlot + (1:symbolsPerSlot);
            slotGrid = rxGrid(:,slotSymbols,:);
            csirsRx = nrExtractResources(csirsIndices,slotGrid);
            if ~any(abs(csirsRx) > 0,"all")
                skippedZeroSlots(end+1,1) = slotIdx; %#ok<AGROW>
                continue;
            end

            csirsSymbols = nrCSIRS(carrier,csirs) * db2mag(powerOffsetDb);
            lsEstimate = csirsRx ./ csirsSymbols;
            numRefs = numel(lsEstimate);
            validRefReCount = validRefReCount + numRefs;
            totalRxPower = totalRxPower + sum(abs(csirsRx).^2,"all");
            totalGridPower = totalGridPower + mean(abs(slotGrid).^2,"all") * numRefs;
            totalAbsLs = totalAbsLs + sum(abs(lsEstimate),"all");
            activeSlots(end+1,1) = slotIdx; %#ok<AGROW>
        end

        resultIdx = resultIdx + 1;
        scanResults(resultIdx).slotOffset = slotOffset;
        scanResults(resultIdx).subcarrierLocation = subcarrierLocation;
        scanResults(resultIdx).activeSlots = activeSlots;
        scanResults(resultIdx).skippedZeroSlots = skippedZeroSlots;
        scanResults(resultIdx).validRefReCount = validRefReCount;
        if validRefReCount == 0
            scanResults(resultIdx).meanRxPower = NaN;
            scanResults(resultIdx).relativePowerDb = -Inf;
            scanResults(resultIdx).meanAbsLs = NaN;
            scanResults(resultIdx).score = -Inf;
            scanResults(resultIdx).status = "no_nonzero_occurrence";
        else
            meanRxPower = totalRxPower / validRefReCount;
            relativePowerDb = 10*log10((totalRxPower + eps) / (totalGridPower + eps));
            scanResults(resultIdx).meanRxPower = meanRxPower;
            scanResults(resultIdx).relativePowerDb = relativePowerDb;
            scanResults(resultIdx).meanAbsLs = totalAbsLs / validRefReCount;
            scanResults(resultIdx).score = relativePowerDb;
            scanResults(resultIdx).status = "scored";
        end
    end
end

if ~isempty(scanResults)
    [~,order] = sort([scanResults.score],"descend");
    scanResults = scanResults(order);
end
end

function [slotOffset,subcarrierLocation,selection] = selectCsirsCandidate(scanResults)
slotOffset = 6;
subcarrierLocation = 0;
selection = "Fallback fixed assumption: slotOffset=6, subcarrierLocation=0.";

if isempty(scanResults) || ~isfinite(scanResults(1).score)
    return;
end

slotOffset = scanResults(1).slotOffset;
subcarrierLocation = scanResults(1).subcarrierLocation;
selection = sprintf("Selected top row-1 candidate from scan: slotOffset=%d, subcarrierLocation=%d, relativePower=%.3f dB.", ...
    slotOffset,subcarrierLocation,scanResults(1).relativePowerDb);
end

function [carrier,csirs] = buildCsirsRow1Config(ncellid,scsCommon,nframe,visibleNSizeGrid,slotOffset,subcarrierLocation)
carrier = nrCarrierConfig;
carrier.NCellID = ncellid;
carrier.SubcarrierSpacing = scsCommon;
carrier.NStartGrid = 0;
carrier.NSizeGrid = visibleNSizeGrid;
carrier.NFrame = nframe;

csirs = nrCSIRSConfig;
csirs.CSIRSType = {"nzp","nzp"};
csirs.CSIRSPeriod = {[40 slotOffset],[40 slotOffset]};
csirs.RowNumber = [1 1];
csirs.Density = {"three","three"};
csirs.SymbolLocations = {6,10};
csirs.SubcarrierLocations = {subcarrierLocation,subcarrierLocation};
csirs.RBOffset = 0;
csirs.NumRB = visibleNSizeGrid;
csirs.NID = ncellid;
end

function [carrier,csirs,assumptions] = buildCsirsCandidateConfig(ncellid,scsCommon,nframe,visibleNSizeGrid,slotOffset,subcarrierLocation,powerOffsetDb)
[carrier,csirs] = buildCsirsRow1Config(ncellid,scsCommon,nframe,visibleNSizeGrid,slotOffset,subcarrierLocation);

assumptions = struct();
assumptions.type = "TRS / NZP CSI-RS candidate";
assumptions.NID = ncellid;
assumptions.NIDSource = "Assumed equal to detected PCI/NCellID";
assumptions.periodicitySlots = 40;
assumptions.slotOffset = slotOffset;
assumptions.rowNumber = 1;
assumptions.density = "three";
assumptions.symbolLocations = [6 10];
assumptions.subcarrierLocations = subcarrierLocation;
assumptions.RBOffset = 0;
assumptions.powerOffsetDb = powerOffsetDb;
assumptions.nominalSlotOffset = 6;
assumptions.nominalSubcarrierLocation = 0;
assumptions.requestedCarrierNSizeGrid = 273;
assumptions.appliedCarrierNSizeGrid = visibleNSizeGrid;
assumptions.cdmType = string(csirs.CDMType{1});
assumptions.numPorts = csirs.NumCSIRSPorts(1);
end

function cdmLengths = cdmLengthsFromCsirs(csirs)
cdmType = string(csirs.CDMType{1});
switch cdmType
    case "noCDM"
        cdmLengths = [1 1];
    case "FD-CDM2"
        cdmLengths = [2 1];
    case "CDM4"
        cdmLengths = [2 2];
    case "CDM8"
        cdmLengths = [2 4];
    otherwise
        error("extractCsirsCandidateCsi:UnsupportedCSIRSCDM", ...
            "Unsupported CSI-RS CDMType: %s.",cdmType);
end
end
