function frequencyHz = nrArfcnToHz(nrarfcn)
%NRARFCNTOHZ Convert NR-ARFCN to center frequency in Hz.
%   This implementation covers FR1 and is sufficient for the n79 target in
%   this repository. The mapping follows the 3GPP TS 38.104 global raster.

validateattributes(nrarfcn, {'numeric'}, {'scalar', 'real', 'finite', 'integer', 'nonnegative'}, mfilename, 'nrarfcn');

if nrarfcn <= 599999
    deltaFGlobalKHz = 5;
    fRefOffsMHz = 0;
    nRefOffs = 0;
elseif nrarfcn <= 2016666
    deltaFGlobalKHz = 15;
    fRefOffsMHz = 3000;
    nRefOffs = 600000;
else
    error('nrArfcnToHz:OutOfRange', 'NR-ARFCN %d is outside the supported FR1/FR2 raster range.', nrarfcn);
end

frequencyHz = (fRefOffsMHz * 1e6) + ((double(nrarfcn) - nRefOffs) * deltaFGlobalKHz * 1e3);
end
