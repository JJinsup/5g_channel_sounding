function cfoResult = correctCFO(waveform, scsKHz, cfg, sampleRate)
%CORRECTCFO Estimate and correct CFO using CP correlation.
%   This is a simple practical estimator intended for debug and first-pass
%   stabilization before OFDM demodulation.

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
nfft = ofdmInfo.Nfft;
cpLengths = ofdmInfo.CyclicPrefixLengths(:);
symbolLengths = ofdmInfo.SymbolLengths(:);

numSymbolsAvailable = min(numel(symbolLengths), cfg.sync.cfoMaxSymbols);
waveformLength = numel(waveform);
symbolStart = 1;
correlationTerms = complex(zeros(numSymbolsAvailable, 1));
usedSymbols = false(numSymbolsAvailable, 1);

for symIdx = 1:numSymbolsAvailable
    cpLen = cpLengths(symIdx);
    symLen = symbolLengths(symIdx);
    symbolStop = symbolStart + symLen - 1;
    tailStart = symbolStart + cpLen + nfft - cpLen;
    tailStop = symbolStart + cpLen + nfft - 1;

    if symbolStop > waveformLength || tailStop > waveformLength
        break;
    end

    cpSamples = waveform(symbolStart:(symbolStart + cpLen - 1));
    tailSamples = waveform(tailStart:tailStop);
    correlationTerms(symIdx) = sum(conj(cpSamples) .* tailSamples);
    usedSymbols(symIdx) = true;
    symbolStart = symbolStart + symLen;
end

validTerms = correlationTerms(usedSymbols);
if isempty(validTerms)
    error('correctCFO:InsufficientSamples', ...
        'Unable to estimate CFO because no complete OFDM symbols were available.');
end

combinedCorrelation = sum(validTerms);
estimatedCfoHz = angle(combinedCorrelation) * sampleRate / (2 * pi * nfft);
sampleIndex = (0:waveformLength - 1).';
correctedWaveform = waveform .* exp(-1j * 2 * pi * estimatedCfoHz * sampleIndex / sampleRate);

cfoResult = struct();
cfoResult.estimatedCfoHz = estimatedCfoHz;
cfoResult.correctedWaveform = correctedWaveform;
cfoResult.ofdmInfo = ofdmInfo;
cfoResult.numSymbolsUsed = nnz(usedSymbols);
cfoResult.correlationTerms = validTerms;
cfoResult.combinedCorrelation = combinedCorrelation;
cfoResult.method = 'cp-correlation';
end
