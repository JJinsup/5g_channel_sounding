function gridResult = buildResourceGrid(waveform, scsKHz, cfg, sampleRate)
%BUILDRESOURCEGRID Demodulate a synchronized waveform into an NR resource grid.
%   Uses only currently available 5G Toolbox functions.

arguments
    waveform (:,1) double
    scsKHz (1,1) double
    cfg (1,1) struct
    sampleRate (1,1) double
end

carrier = nrCarrierConfig;
carrier.NSizeGrid = cfg.grid.nSizeGrid;
carrier.NStartGrid = cfg.grid.nStartGrid;
carrier.SubcarrierSpacing = scsKHz;
carrier.CyclicPrefix = cfg.grid.cyclicPrefix;
carrier.NSlot = cfg.sync.initialSlot;
carrier.NFrame = 0;

ofdmInfo = nrOFDMInfo(carrier, 'SampleRate', sampleRate);
grid = nrOFDMDemodulate(carrier, waveform, 'SampleRate', sampleRate);

gridResult = struct();
gridResult.carrier = carrier;
gridResult.ofdmInfo = ofdmInfo;
gridResult.grid = grid;
gridResult.gridSize = size(grid);
gridResult.numSubcarriers = size(grid, 1);
gridResult.numSymbols = size(grid, 2);
end
