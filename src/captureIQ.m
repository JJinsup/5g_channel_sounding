function capture = captureIQ(rx, cfg, runtime)
%CAPTUREIQ Capture raw IQ frames and persist metadata-friendly outputs.
%   This function is intentionally conservative: it captures, checks for
%   overflow, and saves enough context for offline debugging.

arguments
    rx
    cfg (1,1) struct
    runtime (1,1) struct
end

prepareOutputDirs(cfg.paths);

numFrames = cfg.capture.numFrames;
samplesPerFrame = cfg.capture.samplesPerFrame;
iq = complex(zeros(numFrames * samplesPerFrame, 1, 'double'));
overrunFlags = false(numFrames, 1);
validFrameCount = 0;
writeIndex = 1;
frameLengths = zeros(numFrames, 1);

captureStart = datetime('now', 'TimeZone', 'local', 'Format', 'yyyy-MM-dd HH:mm:ss.SSS Z');

for frameIdx = 1:numFrames
    [frame, len, overrun] = rx();

    if len <= 0
        warning('captureIQ:EmptyFrame', 'Received an empty frame at iteration %d.', frameIdx);
        continue;
    end

    startIdx = writeIndex;
    stopIdx = startIdx + len - 1;
    iq(startIdx:stopIdx) = frame(1:len);
    writeIndex = stopIdx + 1;
    validFrameCount = validFrameCount + 1;
    frameLengths(frameIdx) = len;
    overrunFlags(frameIdx) = logical(overrun);
end

captureEnd = datetime('now', 'TimeZone', 'local', 'Format', 'yyyy-MM-dd HH:mm:ss.SSS Z');
iq = iq(1:(writeIndex - 1));

if isempty(iq)
    error('captureIQ:NoSamplesCaptured', 'No IQ samples were captured from the radio.');
end

runStamp = char(datetime('now', 'TimeZone', 'local', 'Format', 'yyyyMMdd_HHmmss'));
baseName = sprintf('capture_%s_fc_%0.3fMHz_sr_%0.2fMSps', runStamp, cfg.radio.centerFrequencyHz / 1e6, cfg.radio.sampleRate / 1e6);
outputMatPath = fullfile(cfg.paths.rawIqRoot, [baseName '.mat']);
durationBucket = getDurationBucketName(cfg.capture.durationMs);
figureRoot = fullfile(cfg.paths.figuresRoot, durationBucket);
mkdirIfMissing(figureRoot);
outputFigurePath = fullfile(figureRoot, [baseName '_spectrum.png']);

metadata = struct();
metadata.captureStart = captureStart;
metadata.captureEnd = captureEnd;
metadata.centerFrequencyHz = cfg.radio.centerFrequencyHz;
metadata.sampleRate = cfg.radio.sampleRate;
metadata.masterClockRate = cfg.radio.masterClockRate;
metadata.gain = cfg.radio.gain;
metadata.requestedDurationMs = cfg.capture.durationMs;
metadata.samplesPerFrame = samplesPerFrame;
metadata.requestedNumFrames = numFrames;
metadata.validFrameCount = validFrameCount;
metadata.frameLengths = frameLengths;
metadata.samplesCaptured = numel(iq);
metadata.overflowFlags = overrunFlags;
metadata.overflowDetected = any(overrunFlags);
metadata.clockSource = cfg.radio.clockSource;
metadata.ppsSource = cfg.radio.ppsSource;
metadata.runtime = runtime;
metadata.band = cfg.metadata.band;
metadata.plmn = cfg.metadata.plmn;
metadata.notes = cfg.metadata.notes;

capture = struct();
capture.iq = iq;
capture.metadata = metadata;
capture.outputMatPath = outputMatPath;
capture.outputFigurePath = outputFigurePath;
end

function prepareOutputDirs(paths)
mkdirIfMissing(paths.outputRoot);
mkdirIfMissing(paths.rawIqRoot);
mkdirIfMissing(paths.processedRoot);
mkdirIfMissing(paths.figuresRoot);
mkdirIfMissing(paths.logsRoot);
end

function mkdirIfMissing(pathStr)
if ~isfolder(pathStr)
    mkdir(pathStr);
end
end
