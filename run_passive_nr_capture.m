function results = run_passive_nr_capture(overrides)
%RUN_PASSIVE_NR_CAPTURE First-pass passive NR capture entry point.
%   Optional overrides allow parameter sweeps without hand-editing config.

if nargin < 1
    overrides = struct();
end

clc;

repoRoot = fileparts(mfilename('fullpath'));
addpath(fullfile(repoRoot, 'config'));
addpath(fullfile(repoRoot, 'src'));

cfg = default_config(repoRoot, overrides);
runInfo = struct();
runInfo.startTime = datetime('now', 'TimeZone', 'local', 'Format', 'yyyy-MM-dd HH:mm:ss.SSS Z');
runInfo.status = 'started';

fprintf('=== Passive NR Capture: Initial Hardware Validation ===\n');
fprintf('Center frequency target: %.3f MHz\n', cfg.radio.centerFrequencyHz / 1e6);
fprintf('Sample rate: %.2f MSps\n', cfg.radio.sampleRate / 1e6);
fprintf('Capture duration: %.1f ms\n', cfg.capture.durationMs);
fprintf('Output root: %s\n\n', cfg.paths.outputRoot);

rx = [];
cleanupObj = onCleanup(@() releaseReceiver(rx)); %#ok<NASGU>

try
    [rx, runtime] = initB210Receiver(cfg);
    capture = captureIQ(rx, cfg, runtime);

    runInfo.status = 'capture_complete';
    runInfo.endTime = datetime('now', 'TimeZone', 'local', 'Format', 'yyyy-MM-dd HH:mm:ss.SSS Z');

    diagnostics = buildCaptureDiagnostics(capture.iq, cfg, capture.metadata);

    results = struct();
    results.config = cfg;
    results.runtime = runtime;
    results.capture = capture;
    results.diagnostics = diagnostics;
    results.runInfo = runInfo;

    save(capture.outputMatPath, 'results', '-v7.3');
    plotCaptureDiagnostics(capture.iq, cfg, capture.metadata, diagnostics, capture.outputFigurePath);

    fprintf('Capture completed successfully.\n');
    fprintf('Samples captured: %d\n', size(capture.iq, 1));
    fprintf('Overflow detected: %s\n', string(capture.metadata.overflowDetected));
    fprintf('Peak magnitude: %.3f\n', diagnostics.timeDomain.peakMagnitude);
    fprintf('RMS magnitude: %.3f\n', diagnostics.timeDomain.rmsMagnitude);
    fprintf('Saved MAT file: %s\n', capture.outputMatPath);
    fprintf('Saved diagnostics figure: %s\n', capture.outputFigurePath);
catch ME
    runInfo.status = 'failed';
    runInfo.endTime = datetime('now', 'TimeZone', 'local', 'Format', 'yyyy-MM-dd HH:mm:ss.SSS Z');
    warning('Passive NRCapture failed: %s', ME.message);
    rethrow(ME);
end
end

function releaseReceiver(rx)
if ~isempty(rx)
    release(rx);
end
end

function diagnostics = buildCaptureDiagnostics(iq, cfg, metadata)
if isempty(iq)
    error('buildCaptureDiagnostics:EmptyIQ', 'IQ data is empty.');
end

fs = cfg.radio.sampleRate;
maxPsdSamples = min(numel(iq), max(cfg.diagnostics.psdSegmentLength * cfg.diagnostics.maxPsdSegments, cfg.diagnostics.psdSegmentLength));
iqForPsd = iq(1:maxPsdSamples);
[pxx, freqAxis] = pwelch(iqForPsd, hann(cfg.diagnostics.psdSegmentLength, 'periodic'), [], cfg.diagnostics.spectrumNfft, fs, 'centered');
psdDb = 10 * log10(pxx + eps);

previewLength = min(numel(iq), cfg.diagnostics.timePreviewSamples);
timePreview = iq(1:previewLength);
timeAxisUs = (0:previewLength - 1).' / fs * 1e6;

magnitude = abs(iq);
peakMagnitude = max(magnitude);
rmsMagnitude = sqrt(mean(magnitude .^ 2));
meanI = mean(real(iq));
meanQ = mean(imag(iq));
peakToRmsRatio = peakMagnitude / max(rmsMagnitude, eps);

clipThreshold = cfg.diagnostics.clipLevel;
clipFraction = mean(abs(real(iq)) >= clipThreshold | abs(imag(iq)) >= clipThreshold);

diagnostics = struct();
diagnostics.psd = struct();
diagnostics.psd.freqAxisMHz = freqAxis / 1e6;
diagnostics.psd.powerDb = psdDb;
diagnostics.psd.maxPowerDb = max(psdDb);
diagnostics.psd.minPowerDb = min(psdDb);

diagnostics.timeDomain = struct();
diagnostics.timeDomain.previewTimeUs = timeAxisUs;
diagnostics.timeDomain.previewI = real(timePreview);
diagnostics.timeDomain.previewQ = imag(timePreview);
diagnostics.timeDomain.previewMagnitude = abs(timePreview);
diagnostics.timeDomain.peakMagnitude = peakMagnitude;
diagnostics.timeDomain.rmsMagnitude = rmsMagnitude;
diagnostics.timeDomain.peakToRmsRatio = peakToRmsRatio;
diagnostics.timeDomain.meanI = meanI;
diagnostics.timeDomain.meanQ = meanQ;
diagnostics.timeDomain.clipFraction = clipFraction;

diagnostics.capture = struct();
diagnostics.capture.samplesCaptured = metadata.samplesCaptured;
diagnostics.capture.overflowDetected = metadata.overflowDetected;
diagnostics.capture.validFrameCount = metadata.validFrameCount;
diagnostics.capture.requestedNumFrames = metadata.requestedNumFrames;
end

function plotCaptureDiagnostics(iq, cfg, metadata, diagnostics, outputFigurePath)
if isempty(iq)
    warning('plotCaptureDiagnostics:EmptyIQ', 'Skipping diagnostics plot because IQ is empty.');
    return;
end

fig = figure('Visible', cfg.diagnostics.figureVisibility, 'Color', 'w', 'Position', [100 100 1200 900]);
tiledlayout(fig, 2, 2, 'Padding', 'compact', 'TileSpacing', 'compact');

nexttile;
plot(diagnostics.psd.freqAxisMHz, diagnostics.psd.powerDb, 'LineWidth', 1.1);
grid on;
xlabel('Relative Frequency (MHz)');
ylabel('PSD (dB/Hz)');
title('Averaged PSD (pwelch)');

nexttile;
plot(diagnostics.timeDomain.previewTimeUs, diagnostics.timeDomain.previewI, 'LineWidth', 0.9);
hold on;
plot(diagnostics.timeDomain.previewTimeUs, diagnostics.timeDomain.previewQ, 'LineWidth', 0.9);
grid on;
xlabel('Time (us)');
ylabel('Amplitude');
title('Time-Domain Preview');
legend('I', 'Q', 'Location', 'best');

nexttile;
histogram(abs(iq), cfg.diagnostics.histogramBins, 'Normalization', 'pdf');
grid on;
xlabel('|IQ|');
ylabel('PDF');
title('Magnitude Distribution');

nexttile;
text(0.01, 0.92, sprintf('Samples captured: %d', metadata.samplesCaptured), 'FontSize', 11);
text(0.01, 0.78, sprintf('Overflow detected: %s', string(metadata.overflowDetected)), 'FontSize', 11);
text(0.01, 0.64, sprintf('Valid frames: %d / %d', metadata.validFrameCount, metadata.requestedNumFrames), 'FontSize', 11);
text(0.01, 0.50, sprintf('Peak magnitude: %.4f', diagnostics.timeDomain.peakMagnitude), 'FontSize', 11);
text(0.01, 0.36, sprintf('RMS magnitude: %.4f', diagnostics.timeDomain.rmsMagnitude), 'FontSize', 11);
text(0.01, 0.22, sprintf('Peak/RMS ratio: %.4f', diagnostics.timeDomain.peakToRmsRatio), 'FontSize', 11);
text(0.01, 0.08, sprintf('Clip fraction: %.6f | Mean I/Q: %.4e / %.4e', diagnostics.timeDomain.clipFraction, diagnostics.timeDomain.meanI, diagnostics.timeDomain.meanQ), 'FontSize', 11);
axis off;
title('Capture Summary');

sgtitle('Passive NR Capture Diagnostics');
saveas(fig, outputFigurePath);
close(fig);
end
