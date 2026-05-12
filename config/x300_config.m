function overrides = x300_config()
%X300_CONFIG Receive-only profile for USRP X300/X310-series + UBX-160.

overrides = struct();

overrides.radio = struct();
overrides.radio.deviceSeries = "x300";
overrides.radio.serialNum = '192.168.40.2'; % X300/X310 10GbE DeviceAddress/IPAddress.
overrides.radio.gain = 25;
overrides.radio.channelMapping = 1;
overrides.radio.transportDataType = 'int16';
overrides.radio.outputDataType = 'single';

overrides.ssbCapture = struct();
overrides.ssbCapture.deviceName = "X300"; % Use "X310" here for an actual X310 platform.
overrides.ssbCapture.sampleRate = 184.32e6;
overrides.ssbCapture.fileNamePrefix = "capturedWaveform_x300";

overrides.receiver = struct();
overrides.receiver.csirsGridMode = "carrier";
overrides.receiver.csirsCarrierNSizeGrid = 273;
end
