function syncResult = correctTimingOffset(iq, timingOffset, cfg)
%CORRECTTIMINGOFFSET Apply timing correction and return synchronized waveform.
%   This helper trims the waveform to the detected timing origin and keeps
%   enough metadata for later OFDM/grid steps.

arguments
    iq (:,1) double
    timingOffset (1,1) double {mustBeInteger, mustBeNonnegative}
    cfg (1,1) struct
end

sampleCount = numel(iq);
startSample = min(sampleCount, timingOffset + 1);
synchronizedWaveform = iq(startSample:end);

if numel(synchronizedWaveform) < cfg.sync.minWaveformSamples
    error('correctTimingOffset:ShortWaveform', ...
        'Only %d synchronized samples remain after timing correction.', numel(synchronizedWaveform));
end

syncResult = struct();
syncResult.timingOffset = timingOffset;
syncResult.startSample = startSample;
syncResult.synchronizedWaveform = synchronizedWaveform;
syncResult.samplesRemaining = numel(synchronizedWaveform);
end
