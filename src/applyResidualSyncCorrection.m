function residualSyncResult = applyResidualSyncCorrection(waveform, sampleRate, residualCfoHz, residualTimingSamples)
%APPLYRESIDUALSYNCCORRECTION Apply residual CFO and timing correction.
%   This helper is intentionally simple and sits immediately before OFDM
%   demodulation so we can flatten residual phase slope during debug.

arguments
    waveform (:,1) double
    sampleRate (1,1) double
    residualCfoHz (1,1) double
    residualTimingSamples (1,1) double
end

sampleIndex = (0:numel(waveform) - 1).';
correctedWaveform = waveform;

% Residual CFO is applied as a time-domain inverse phase rotation.
if residualCfoHz ~= 0
    correctedWaveform = correctedWaveform .* exp(-1j * 2 * pi * residualCfoHz * sampleIndex / sampleRate);
end

% Residual timing is implemented as an FFT-domain fractional delay.
if residualTimingSamples ~= 0
    numSamples = numel(correctedWaveform);
    freqBins = ifftshift((-floor(numSamples / 2)):(ceil(numSamples / 2) - 1)).';
    % Use the inverse sign so residual timing correction derotates the
    % measured phase slope instead of mirroring it.
    phaseRamp = exp(1j * 2 * pi * residualTimingSamples * freqBins / numSamples);
    correctedWaveform = ifft(fft(correctedWaveform) .* phaseRamp);
end

residualSyncResult = struct();
residualSyncResult.correctedWaveform = correctedWaveform;
residualSyncResult.appliedResidualCfoHz = residualCfoHz;
residualSyncResult.appliedResidualTimingSamples = residualTimingSamples;
residualSyncResult.method = 'time-domain CFO rotation + FFT fractional delay';
end
