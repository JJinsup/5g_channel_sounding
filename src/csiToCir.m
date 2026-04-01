function cirResult = csiToCir(csiVector, sampleRate, scsKHz, cfg)
%CSITOCIR Convert an interpolated surrogate CFR into a partial-band effective CIR/PDP surrogate.
%   This result is derived from a partial-band, hypothesis-conditioned CFR
%   estimate and must not be interpreted as full-band or absolute-delay CSI.

arguments
    csiVector (:,1) double
    sampleRate (1,1) double
    scsKHz (1,1) double
    cfg (1,1) struct
end

numSubcarriers = numel(csiVector);
fftLength = cfg.cir.zeroPadFactor * numSubcarriers;
preprocess = preprocessCsiVector(csiVector, cfg);
windowedCSI = preprocess.preparedCSI;

cir = ifft(windowedCSI, fftLength);
cirMagnitude = abs(cir);
pdp = cirMagnitude .^ 2;

% Use an fftshifted view so the delay axis is centered and easier to inspect.
cirCentered = fftshift(cir);
cirCenteredMagnitude = abs(cirCentered);
pdpCentered = cirCenteredMagnitude .^ 2;

effectiveBandwidthHz = numSubcarriers * scsKHz * 1e3;
delayResolutionSeconds = 1 / (fftLength * scsKHz * 1e3);
delayAxisSeconds = (0:fftLength - 1).' * delayResolutionSeconds;
centeredDelayAxisSeconds = ((-floor(fftLength / 2)):(ceil(fftLength / 2) - 1)).' * delayResolutionSeconds;

[~, peakIndex] = max(pdp);
peakDelaySeconds = delayAxisSeconds(peakIndex);

[~, centeredPeakIndex] = max(pdpCentered);
centeredPeakDelaySeconds = centeredDelayAxisSeconds(centeredPeakIndex);

peakCenteredCir = circshift(cirCentered, -centeredPeakIndex + ceil(fftLength / 2));
peakCenteredCirMagnitude = abs(peakCenteredCir);
peakCenteredPdp = peakCenteredCirMagnitude .^ 2;
peakCenteredDelayAxisSeconds = centeredDelayAxisSeconds - centeredDelayAxisSeconds(ceil(fftLength / 2));

pdpCenteredDb = 10 * log10(pdpCentered + eps);
thresholdDb = max(pdpCenteredDb) + cfg.cir.tapThresholdDb;
thresholdMask = pdpCenteredDb >= thresholdDb;
thresholdedPdpCentered = pdpCentered;
thresholdedPdpCentered(~thresholdMask) = 0;

peakCenteredPdpDb = 10 * log10(peakCenteredPdp + eps);
peakCenteredThresholdDb = max(peakCenteredPdpDb) + cfg.cir.tapThresholdDb;
peakCenteredThresholdMask = peakCenteredPdpDb >= peakCenteredThresholdDb;
thresholdedPeakCenteredPdp = peakCenteredPdp;
thresholdedPeakCenteredPdp(~peakCenteredThresholdMask) = 0;

% Build a relative-delay visualization window that starts at the earliest
% threshold-crossing bin inside the peak-aligned display.
significantTapIdx = find(peakCenteredThresholdMask, 1, 'first');
if isempty(significantTapIdx)
    significantTapIdx = ceil(fftLength / 2);
end
causalCir = peakCenteredCir(significantTapIdx:end);
causalPdp = peakCenteredPdp(significantTapIdx:end);
causalDelayAxisSeconds = peakCenteredDelayAxisSeconds(significantTapIdx:end);
causalDelayAxisSeconds = causalDelayAxisSeconds - causalDelayAxisSeconds(1);
causalCirNormalized = abs(causalCir) ./ max(abs(causalCir) + eps);
[~, strongestTapRelativeIdx] = max(abs(causalCir));
strongestTapDelaySeconds = causalDelayAxisSeconds(strongestTapRelativeIdx);

cirResult = struct();
cirResult.csiVector = csiVector;
cirResult.preprocess = preprocess;
cirResult.windowedCSI = windowedCSI;
cirResult.cir = cir;
cirResult.cirMagnitude = cirMagnitude;
cirResult.pdp = pdp;
cirResult.delayAxisSeconds = delayAxisSeconds;
cirResult.peakIndex = peakIndex;
cirResult.peakDelaySeconds = peakDelaySeconds;
cirResult.cirCentered = cirCentered;
cirResult.cirCenteredMagnitude = cirCenteredMagnitude;
cirResult.pdpCentered = pdpCentered;
cirResult.thresholdedPdpCentered = thresholdedPdpCentered;
cirResult.centeredDelayAxisSeconds = centeredDelayAxisSeconds;
cirResult.centeredPeakIndex = centeredPeakIndex;
cirResult.centeredPeakDelaySeconds = centeredPeakDelaySeconds;
cirResult.peakCenteredCir = peakCenteredCir;
cirResult.peakCenteredCirMagnitude = peakCenteredCirMagnitude;
cirResult.peakCenteredPdp = peakCenteredPdp;
cirResult.thresholdedPeakCenteredPdp = thresholdedPeakCenteredPdp;
cirResult.peakCenteredDelayAxisSeconds = peakCenteredDelayAxisSeconds;
cirResult.causalCir = causalCir;
cirResult.causalPdp = causalPdp;
cirResult.causalDelayAxisSeconds = causalDelayAxisSeconds;
cirResult.causalCirNormalized = causalCirNormalized;
cirResult.firstSignificantTapIndex = significantTapIdx;
cirResult.firstSignificantTapDelaySeconds = 0;
cirResult.strongestTapRelativeIndex = strongestTapRelativeIdx;
cirResult.strongestTapDelaySeconds = strongestTapDelaySeconds;
cirResult.fftLength = fftLength;
cirResult.effectiveBandwidthHz = effectiveBandwidthHz;
cirResult.delayResolutionSeconds = delayResolutionSeconds;
cirResult.sampleRate = sampleRate;
cirResult.scsKHz = scsKHz;
cirResult.dominantRelativeDelaySeconds = peakDelaySeconds;
cirResult.centeredDominantRelativeDelaySeconds = centeredPeakDelaySeconds;
cirResult.peakAlignedRelativeDelayAxisSeconds = peakCenteredDelayAxisSeconds;
cirResult.relativeVisualizationDelayAxisSeconds = causalDelayAxisSeconds;
cirResult.relativeVisualizationMagnitude = causalCirNormalized;
cirResult.note = sprintf(['Partial-band effective CIR derived from interpolated PBCH DM-RS CSI. ' ...
    'Phase flattening: %s. Window: %s. ' ...
    'Use centeredDelayAxisSeconds for fftshifted inspection and relativeVisualizationDelayAxisSeconds as a relative visualization axis only.'], ...
    char(string(preprocess.phaseFlatteningEnabled)), char(string(preprocess.windowName)));
cirResult.derivedSurrogateObservables = struct( ...
    'inputInterpolatedSurrogateCfr', csiVector, ...
    'partialBandEffectiveCirSurrogate', cir, ...
    'partialBandEffectivePdpSurrogate', pdp, ...
    'relativeIfftDelayAxisSeconds', delayAxisSeconds, ...
    'peakAlignedRelativeDelayAxisSeconds', peakCenteredDelayAxisSeconds, ...
    'relativeVisualizationDelayAxisSeconds', causalDelayAxisSeconds);
end

function preprocess = preprocessCsiVector(csiVector, cfg)
numSubcarriers = numel(csiVector);
subcarrierAxis = (1:numSubcarriers).';
rawMagnitude = abs(csiVector);
rawPhase = unwrap(angle(csiVector));
phaseFitMask = false(numSubcarriers, 1);
coeffs = [0 0];
phaseFlattenedCSI = csiVector;
phaseFlattenedMagnitude = rawMagnitude;
phaseFlattenedPhase = rawPhase;

if isfield(cfg.cir, 'enablePhaseFlattening') && cfg.cir.enablePhaseFlattening
    phaseFitMask = rawMagnitude >= cfg.cir.phaseFitMagnitudeFraction * max(rawMagnitude + eps);
    if nnz(phaseFitMask) < 4
        phaseFitMask = true(numSubcarriers, 1);
    end

    coeffs = polyfit(double(subcarrierAxis(phaseFitMask)), rawPhase(phaseFitMask), 1);
    phaseFlattenedCSI = csiVector .* exp(-1j * (coeffs(1) * subcarrierAxis + coeffs(2)));
    phaseFlattenedMagnitude = abs(phaseFlattenedCSI);
    phaseFlattenedPhase = unwrap(angle(phaseFlattenedCSI));
end

trimCount = floor(cfg.cir.edgeTrimFraction * numSubcarriers);
trustedMask = true(numSubcarriers, 1);
if 2 * trimCount < numSubcarriers
    trustedMask(1:trimCount) = false;
    trustedMask((numSubcarriers - trimCount + 1):numSubcarriers) = false;
end

taperWindow = zeros(numSubcarriers, 1);
taperWindow(trustedMask) = buildWindow(cfg.cir.window, nnz(trustedMask));
preparedCSI = phaseFlattenedCSI .* taperWindow;

preprocess = struct();
preprocess.rawMagnitude = rawMagnitude;
preprocess.rawPhase = rawPhase;
preprocess.phaseFitMask = phaseFitMask;
preprocess.phaseSlope = coeffs(1);
preprocess.phaseOffset = coeffs(2);
preprocess.phaseFlattenedCSI = phaseFlattenedCSI;
preprocess.phaseFlattenedMagnitude = phaseFlattenedMagnitude;
preprocess.phaseFlattenedPhase = phaseFlattenedPhase;
preprocess.edgeTrimCount = trimCount;
preprocess.trustedMask = trustedMask;
preprocess.taperWindow = taperWindow;
preprocess.preparedCSI = preparedCSI;
preprocess.phaseFlatteningEnabled = isfield(cfg.cir, 'enablePhaseFlattening') && cfg.cir.enablePhaseFlattening;
preprocess.windowName = cfg.cir.window;
end

function window = buildWindow(windowName, numSubcarriers)
switch lower(windowName)
    case {'none', 'rect', 'rectangular'}
        window = ones(numSubcarriers, 1);
    case 'hamming'
        window = hamming(numSubcarriers, 'periodic');
    case 'hann'
        window = hann(numSubcarriers, 'periodic');
    otherwise
        window = ones(numSubcarriers, 1);
end
end
