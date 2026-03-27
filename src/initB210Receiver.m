function [rx, runtime] = initB210Receiver(cfg)
%INITB210RECEIVER Configure a USRP B210 receiver for raw IQ capture.
%   This wrapper keeps SDR setup in one place so later pipeline stages stay
%   hardware-agnostic.

arguments
    cfg (1,1) struct
end

runtime = struct();
runtime.resolvedCenterFrequencyHz = cfg.radio.centerFrequencyHz;
runtime.requestedClockSource = cfg.radio.clockSource;
runtime.requestedPpsSource = cfg.radio.ppsSource;
runtime.initializationTime = datetime('now', 'TimeZone', 'local', 'Format', 'yyyy-MM-dd HH:mm:ss.SSS Z');

receiverArgs = {
    'Platform', cfg.radio.platform, ...
    'CenterFrequency', cfg.radio.centerFrequencyHz, ...
    'MasterClockRate', cfg.radio.masterClockRate, ...
    'DecimationFactor', max(1, round(cfg.radio.masterClockRate / cfg.radio.sampleRate)), ...
    'Gain', cfg.radio.gain, ...
    'SamplesPerFrame', cfg.capture.samplesPerFrame, ...
    'OutputDataType', cfg.radio.outputDataType, ...
    'ChannelMapping', cfg.radio.channelMapping
    };

if ~isempty(cfg.radio.serialNum)
    receiverArgs = [receiverArgs, {'SerialNum', cfg.radio.serialNum}]; %#ok<AGROW>
end

rx = comm.SDRuReceiver(receiverArgs{:});

runtime.clockSourceApplied = false;
runtime.ppsSourceApplied = false;

try
    if isprop(rx, 'ClockSource')
        rx.ClockSource = cfg.radio.clockSource;
        runtime.clockSourceApplied = true;
    end
catch ME
    warning('initB210Receiver:ClockSource', 'Unable to set ClockSource to %s: %s', cfg.radio.clockSource, ME.message);
end

try
    if isprop(rx, 'PPSSource')
        rx.PPSSource = cfg.radio.ppsSource;
        runtime.ppsSourceApplied = true;
    end
catch ME
    warning('initB210Receiver:PPSSource', 'Unable to set PPSSource to %s: %s', cfg.radio.ppsSource, ME.message);
end

runtime.samplesPerFrame = cfg.capture.samplesPerFrame;
runtime.numFrames = cfg.capture.numFrames;
runtime.sampleRate = cfg.radio.sampleRate;
runtime.gain = cfg.radio.gain;
runtime.platform = cfg.radio.platform;
end
