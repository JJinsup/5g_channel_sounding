function overrides = x310_config()
%X310_CONFIG Receive-only profile for USRP X300/X310 wideband captures.

overrides = struct();

overrides.radio = struct();
overrides.radio.deviceSeries = "x300";
overrides.radio.serialNum = ''; % Leave empty to use the first discovered X310 IP.
overrides.radio.gain = 25;
overrides.radio.channelMapping = 1;
overrides.radio.outputDataType = 'single';

overrides.ssbCapture = struct();
overrides.ssbCapture.deviceName = "X310";
overrides.ssbCapture.sampleRate = 184.32e6;
overrides.ssbCapture.fileNamePrefix = "capturedWaveform_x310";

overrides.receiver = struct();
overrides.receiver.csirsGridMode = "carrier";
overrides.receiver.csirsCarrierNSizeGrid = 273;
end
