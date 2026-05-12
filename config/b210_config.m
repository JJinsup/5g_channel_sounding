function overrides = b210_config()
%B210_CONFIG Receive-only profile for USRP B200/B210 captures.

overrides = struct();

overrides.radio = struct();
overrides.radio.deviceSeries = "b200";
overrides.radio.serialNum = '3275420';
overrides.radio.gain = 35;
overrides.radio.channelMapping = 1;
overrides.radio.outputDataType = 'single';

overrides.ssbCapture = struct();
overrides.ssbCapture.deviceName = "B210";
overrides.ssbCapture.sampleRate = 61.44e6;
overrides.ssbCapture.fileNamePrefix = "capturedWaveform_b210";

overrides.receiver = struct();
overrides.receiver.csirsGridMode = "visible";
overrides.receiver.csirsCarrierNSizeGrid = 273;
end
