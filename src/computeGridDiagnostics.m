function diagnostics = computeGridDiagnostics(grid)
%COMPUTEGRIDDIAGNOSTICS Basic magnitude diagnostics for a demodulated grid.

arguments
    grid (:,:,:) double
end

magnitude = abs(grid(:,:,1));
symbolPower = mean(magnitude, 1);
subcarrierPower = mean(magnitude, 2);

[peakSymbolPower, peakSymbolIdx] = max(symbolPower);
[peakSubcarrierPower, peakSubcarrierIdx] = max(subcarrierPower);

diagnostics = struct();
diagnostics.magnitude = magnitude;
diagnostics.symbolPower = symbolPower(:);
diagnostics.subcarrierPower = subcarrierPower(:);
diagnostics.peakSymbolIndex = peakSymbolIdx;
diagnostics.peakSymbolPower = peakSymbolPower;
diagnostics.peakSubcarrierIndex = peakSubcarrierIdx;
diagnostics.peakSubcarrierPower = peakSubcarrierPower;
end
