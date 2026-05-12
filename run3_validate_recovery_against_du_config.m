function validation = run3_validate_recovery_against_du_config(varargin)
%RUN3_VALIDATE_RECOVERY_AGAINST_DU_CONFIG Cross-check recovery MAT with DU CSVs.
%   Loads a *_mib_sib1_recovery.mat result and validates the recovered
%   SSB/MIB/PDCCH/SIB1 facts against exported DU configuration CSV files.
%
%   run3_validate_recovery_against_du_config
%   run3_validate_recovery_against_du_config("RecoveryFile","outputs/2_processed/61.44_260507_mib_sib1_recovery.mat")
%   run3_validate_recovery_against_du_config("ConfigDir","../5g_NW_config")

repoRoot = fileparts(mfilename("fullpath"));

%% User Settings
configuredRecoveryFile = "outputs/2_processed/61.44_260507_mib_sib1_recovery.mat";
configuredConfigDir = fullfile(repoRoot,"..","5g_NW_config");
configuredCellIdentity = [];
configuredSaveReport = true;

opts = parseInputs(varargin{:});
if strlength(opts.recoveryFile) == 0
    opts.recoveryFile = chooseDefaultRecoveryFile(repoRoot,configuredRecoveryFile);
end
if strlength(opts.configDir) == 0
    opts.configDir = configuredConfigDir;
end
if isempty(opts.cellIdentity)
    opts.cellIdentity = configuredCellIdentity;
end
if isempty(opts.saveReport)
    opts.saveReport = configuredSaveReport;
end

recoveryFile = resolvePath(opts.recoveryFile,repoRoot);
configDir = resolvePath(opts.configDir,repoRoot);

loaded = load(recoveryFile,"recovery");
recovery = loaded.recovery;

if isempty(opts.cellIdentity)
    cellIdentity = recovery.sync.NCellID;
else
    cellIdentity = opts.cellIdentity;
end

du = loadDuFacts(configDir,cellIdentity);
checks = buildValidationChecks(recovery,du);
validationTable = struct2table(checks);
csirsCandidateSummary = summarizeCsirsCandidate(recovery);

validation = struct();
validation.recoveryFile = recoveryFile;
validation.configDir = configDir;
validation.cellIdentity = cellIdentity;
validation.duFacts = du;
validation.table = validationTable;
validation.csirsCandidateSummary = csirsCandidateSummary;
validation.summary = summarizeChecks(validationTable);
validation.outputFiles = strings(0,1);

printValidation(validation);

if opts.saveReport
    validationRoot = fullfile(repoRoot,"outputs","3_validation");
    if ~isfolder(validationRoot)
        mkdir(validationRoot);
    end
    timestamp = string(datetime("now","Format","yyyyMMdd_HHmmss"));
    matFile = fullfile(validationRoot,"du_config_validation_" + timestamp + ".mat");
    csvFile = fullfile(validationRoot,"du_config_validation_" + timestamp + ".csv");
    save(matFile,"validation","-v7.3");
    writetable(validationTable,csvFile);
    validation.outputFiles = [string(matFile); string(csvFile)];
    fprintf("Saved validation reports:\n");
    fprintf("  %s\n",validation.outputFiles);
end
end

function opts = parseInputs(varargin)
opts = struct();
opts.recoveryFile = "";
opts.configDir = "";
opts.cellIdentity = [];
opts.saveReport = [];

if isempty(varargin)
    return;
end
if mod(numel(varargin),2) ~= 0
    error("run3_validate_recovery_against_du_config:InvalidInputs", ...
        "Use name-value inputs, for example ""RecoveryFile"",""outputs/2_processed/..."".");
end

for idx = 1:2:numel(varargin)
    name = lower(string(varargin{idx}));
    value = varargin{idx+1};
    switch name
        case {"recoveryfile","resultfile","matfile"}
            opts.recoveryFile = string(value);
        case {"configdir","csvdir","duconfigdir"}
            opts.configDir = string(value);
        case {"cellidentity","cellid","pci","ncellid"}
            opts.cellIdentity = double(value);
        case {"savereport","save"}
            opts.saveReport = parseLogical(value);
        otherwise
            error("run3_validate_recovery_against_du_config:UnknownOption", ...
                "Unknown option: %s.",name);
    end
end
end

function value = parseLogical(value)
if islogical(value)
    return;
end
if isnumeric(value)
    value = value ~= 0;
    return;
end
value = any(strcmpi(string(value),["true" "on" "yes" "1"]));
end

function recoveryFile = chooseDefaultRecoveryFile(repoRoot, configuredRecoveryFile)
recoveryFile = resolvePath(configuredRecoveryFile,repoRoot);
end

function resolved = resolvePath(pathValue, repoRoot)
pathValue = string(pathValue);
if startsWith(pathValue,filesep)
    resolved = pathValue;
elseif isfile(pathValue) || isfolder(pathValue)
    resolved = string(fullfile(pwd,pathValue));
else
    resolved = string(fullfile(repoRoot,pathValue));
end
end

function checks = buildValidationChecks(recovery, du)
checks = emptyCheckArray();

captureFacts = loadCaptureFacts(recovery);

checks = addCheck(checks,"Recovered status", ...
    "sib1_succeeded",recovery.status,recovery.status == "sib1_succeeded", ...
    "MATLAB recovery result","SIB1 recovery should finish successfully.");

checks = addCheck(checks,"Physical cell ID / PCI", ...
    du.physicalCellId,recovery.sync.NCellID,du.physicalCellId == recovery.sync.NCellID, ...
    du.sources.cellPhysical,"DU nr-physical-cell-id must match recovered NCellID.");

checks = addCheck(checks,"PSS NID2 from PCI", ...
    mod(du.physicalCellId,3),recovery.sync.NID2,mod(du.physicalCellId,3) == recovery.sync.NID2, ...
    du.sources.cellPhysical,"NID2 must equal mod(PCI,3).");

checks = addCheck(checks,"SSB ARFCN frequency", ...
    sprintf("%.2f MHz",du.ssbFrequencyMHz),sprintf("%.2f MHz",captureFacts.fPhaseCompMHz), ...
    abs(du.ssbFrequencyMHz - captureFacts.fPhaseCompMHz) < 0.02, ...
    du.sources.ssb,"Capture center should match DU ssb-loc-arfcn.");

checks = addInfo(checks,"DL carrier ARFCN", ...
    sprintf("%d (%.2f MHz)",du.dlArfcn,du.dlCarrierFrequencyMHz), ...
    sprintf("SSB is %.2f MHz below carrier raster",du.dlCarrierFrequencyMHz - du.ssbFrequencyMHz), ...
    du.sources.cellPhysical);

checks = addCheck(checks,"SSB subcarrier spacing", ...
    du.ssbScsKHz,captureFacts.ssbScsKHz,du.ssbScsKHz == captureFacts.ssbScsKHz, ...
    du.sources.ssb,"DU SSB SCS must match capture SSB numerology.");

checks = addCheck(checks,"SSB burst L_max", ...
    du.maxNrOfSsb,captureFacts.Lmax,du.maxNrOfSsb == captureFacts.Lmax, ...
    du.sources.ssb,"DU max-nr-of-ssb must match receiver L_max.");

ssbBitmapPass = false;
if strlength(du.ssbPosition) >= recovery.ssb.ssbIndex + 1
    bitValue = extractBetween(du.ssbPosition,recovery.ssb.ssbIndex+1,recovery.ssb.ssbIndex+1);
    ssbBitmapPass = bitValue == "1";
end
checks = addCheck(checks,"Detected SSB index enabled in bitmap", ...
    du.ssbPosition,"ssbIndex=" + string(recovery.ssb.ssbIndex),ssbBitmapPass, ...
    du.sources.ssb,"DU ssb-position bitmap is checked with zero-based MATLAB ssbIndex.");

checks = addCheck(checks,"Common DL SCS from MIB", ...
    du.dlScsKHz,recovery.mib.initialSystemInfo.SubcarrierSpacingCommon, ...
    du.dlScsKHz == recovery.mib.initialSystemInfo.SubcarrierSpacingCommon, ...
    du.sources.cellEntries,"Recovered MIB common SCS must match DU DL SCS.");

checks = addCheck(checks,"RMSI CORESET index", ...
    du.rmsiCoresetIndex,recovery.mib.initialSystemInfo.PDCCHConfigSIB1.controlResourceSetZero, ...
    du.rmsiCoresetIndex == recovery.mib.initialSystemInfo.PDCCHConfigSIB1.controlResourceSetZero, ...
    du.sources.ssb,"DU rmsi-coreset-index must match MIB PDCCHConfigSIB1.controlResourceSetZero.");

checks = addInfo(checks,"MIB searchSpaceZero", ...
    "DU CSV does not expose a direct value", ...
    recovery.mib.initialSystemInfo.PDCCHConfigSIB1.searchSpaceZero, ...
    "MATLAB recovery result");

checks = addCheck(checks,"DMRS Type A position", ...
    du.dmrsTypeAPosition,recovery.mib.initialSystemInfo.DMRSTypeAPosition, ...
    du.dmrsTypeAPosition == recovery.mib.initialSystemInfo.DMRSTypeAPosition, ...
    du.sources.dlDmrs,"DU dmrs-type-a-position must match recovered MIB.");

checks = addCheck(checks,"SIB1 broadcast configured", ...
    "use",du.sib1Broadcast,du.sib1Broadcast == "use", ...
    du.sources.sibInfo,"DU must be configured to broadcast SIB1.");

checks = addCheck(checks,"SIB1 repetition", ...
    "repetition-20ms",du.sib1Repetition,du.sib1Repetition == "repetition-20ms", ...
    du.sources.bcch,"DU SIB1 repetition should be compatible with observed SIB1 recovery.");

checks = addCheck(checks,"BCH CRC", ...
    0,recovery.mib.bchCRC,recovery.mib.bchCRC == 0, ...
    "MATLAB recovery result","BCH CRC confirms PBCH/MIB decode.");

checks = addCheck(checks,"DCI CRC", ...
    0,recovery.pdcch.dciCRC,recovery.pdcch.dciCRC == 0, ...
    "MATLAB recovery result","SI-RNTI DCI is dynamic; CRC validates the decoded PDCCH candidate.");

checks = addCheck(checks,"SIB1 CRC", ...
    0,recovery.sib1.crc,recovery.sib1.crc == 0, ...
    "MATLAB recovery result","SIB1 CRC confirms DCI-scheduled PDSCH decode.");

checks = addCheck(checks,"SIB1 PDSCH RNTI", ...
    65535,recovery.sib1.pdsch.RNTI,recovery.sib1.pdsch.RNTI == 65535, ...
    "MATLAB recovery result","SI-RNTI must be 65535 for SIB1 scheduling.");

checks = addCheck(checks,"SIB1 PDSCH PRB range inside 100 MHz carrier", ...
    sprintf("0..%d",du.nSizeGrid-1), ...
    sprintf("%d..%d",min(recovery.sib1.pdsch.PRBSet),max(recovery.sib1.pdsch.PRBSet)), ...
    min(recovery.sib1.pdsch.PRBSet) >= 0 && max(recovery.sib1.pdsch.PRBSet) < du.nSizeGrid, ...
    du.sources.cellPhysical,"Decoded SIB1 PDSCH allocation must fit inside DU carrier bandwidth.");

checks = addCheck(checks,"PBCH DM-RS CSI reference count", ...
    144,recovery.csi.pbchDmrsLs.validRefReCount, ...
    recovery.csi.pbchDmrsLs.validRefReCount == 144, ...
    "MATLAB recovery result","PBCH DM-RS sparse CSI should contain 144 reference REs for this SSB.");

checks = addCheck(checks,"PDSCH DM-RS CSI reference count", ...
    "positive",recovery.csi.pdschDmrsLs.validRefReCount, ...
    recovery.csi.pdschDmrsLs.validRefReCount > 0, ...
    "MATLAB recovery result","PDSCH DM-RS sparse CSI should be present when SIB1 succeeds.");

checks = addCsirsValidationChecks(checks,recovery,du);

checks = addInfo(checks,"Known CSV limitation", ...
    "DCI payload is scheduler-dynamic; exact CSI-RS resource mapping is not fully exposed", ...
    "Use CRC/SIB1 success for DCI chain and hypothesis search for TRS/CSI-RS", ...
    "DU CSV review");
end

function checks = addCsirsValidationChecks(checks, recovery, du)
if ~isfield(recovery,"csi") || ~isfield(recovery.csi,"csirsCandidate")
    checks = addInfo(checks,"TRS / NZP CSI-RS candidate", ...
        "candidate extraction info", ...
        "missing: run2 did not store recovery.csi.csirsCandidate", ...
        "MATLAB recovery result");
    return;
end

candidate = recovery.csi.csirsCandidate;
status = getStructField(candidate,"status","");
validRefReCount = getStructField(candidate,"validRefReCount",0);
assumptions = getStructField(candidate,"assumptions",struct());

checks = addInfo(checks,"TRS / NZP CSI-RS candidate status", ...
    "candidate extraction status; not confirmed CSI-RS validation", ...
    sprintf("status=%s, refs=%d",string(status),validRefReCount), ...
    "MATLAB recovery result");

actualPeriodicity = getStructField(assumptions,"periodicitySlots",NaN);
checks = addInfo(checks,"CSI-RS periodicity candidate vs DU CSV", ...
    sprintf("DU csi-rs-periodicity=%s -> %s slots",du.csiRsPeriodicity,valueToString(du.csiRsPeriodicitySlots)), ...
    sprintf("candidate periodicitySlots=%s",valueToString(actualPeriodicity)), ...
    du.sources.csiRs);

checks = addInfo(checks,"TRS periodicity candidate vs DU CSV", ...
    sprintf("DU trs-periodicity=%s -> %s slots",du.trsPeriodicity,valueToString(du.trsPeriodicitySlots)), ...
    sprintf("candidate periodicitySlots=%s",valueToString(actualPeriodicity)), ...
    du.sources.trs);

actualSymbols = getStructField(assumptions,"symbolLocations",[]);
checks = addInfo(checks,"TRS symbol locations candidate vs DU CSV", ...
    sprintf("DU trs-symbol-location=%s -> %s",du.trsSymbolLocation,valueToString(du.trsSymbolLocations)), ...
    sprintf("candidate symbolLocations=%s",valueToString(actualSymbols)), ...
    du.sources.trs);

actualDensity = string(getStructField(assumptions,"density",""));
checks = addInfo(checks,"TRS frequency separation candidate mapping", ...
    sprintf("trs-freq-separation=%d",du.trsFreqSeparationValue), ...
    sprintf("density=%s",actualDensity), ...
    du.sources.trs);

actualPowerOffset = getStructField(assumptions,"powerOffsetDb",NaN);
checks = addInfo(checks,"CSI-RS power offset candidate vs DU CSV", ...
    sprintf("DU csi-rs-power-control-offset=%s -> %s dB",du.csiRsPowerOffset,valueToString(du.csiRsPowerOffsetDb)), ...
    sprintf("candidate powerOffsetDb=%s",valueToString(actualPowerOffset)), ...
    du.sources.csiRs);

actualNid = getStructField(assumptions,"NID",NaN);
checks = addInfo(checks,"CSI-RS candidate NID assumption", ...
    sprintf("detected PCI=%d; CSV does not expose exact CSI-RS scrambling ID",du.physicalCellId), ...
    sprintf("candidate NID=%s",valueToString(actualNid)), ...
    "MATLAB recovery result");

actualRbOffset = getStructField(assumptions,"RBOffset",NaN);
checks = addInfo(checks,"CSI-RS candidate RBOffset assumption", ...
    "BWP CSV shows CBW offset 0; exact CSI-RS RBOffset is not exposed", ...
    sprintf("candidate RBOffset=%s",valueToString(actualRbOffset)), ...
    "MATLAB recovery result");

actualNSizeGrid = getStructField(assumptions,"appliedCarrierNSizeGrid",NaN);
checks = addInfo(checks,"CSI-RS candidate grid size vs DU carrier", ...
    sprintf("DU 100 MHz / 30 kHz carrier grid=%s RB",valueToString(du.nSizeGrid)), ...
    sprintf("candidate appliedCarrierNSizeGrid=%s RB",valueToString(actualNSizeGrid)), ...
    du.sources.cellPhysical);

checks = addInfo(checks,"CSI-RS exact mapping still unverified", ...
    "row/ports/CDM/subcarrierLocation/slotOffset/scramblingID from gNB config", ...
    sprintf("candidate row=%s, ports=%s, CDM=%s, slotOffset=%s, subcarrierLocation=%s", ...
    valueToString(getStructField(assumptions,"rowNumber",NaN)), ...
    valueToString(getStructField(assumptions,"numPorts",NaN)), ...
    valueToString(getStructField(assumptions,"cdmType","")), ...
    valueToString(getStructField(assumptions,"slotOffset",NaN)), ...
    valueToString(getStructField(assumptions,"subcarrierLocations",NaN))), ...
    "DU CSV limitation");
end

function summary = summarizeCsirsCandidate(recovery)
summary = struct();
summary.available = false;
summary.status = "";
summary.validRefReCount = 0;
summary.selection = "";
summary.slotOffset = NaN;
summary.subcarrierLocation = NaN;
summary.relativePowerDb = NaN;
summary.meanAbsLs = NaN;
summary.activeSlots = [];
summary.note = "CSI-RS candidate scan only; not confirmed gNB CSI-RS configuration.";

if ~isfield(recovery,"csi") || ~isfield(recovery.csi,"csirsCandidate")
    return;
end

candidate = recovery.csi.csirsCandidate;
summary.available = true;
summary.status = string(getStructField(candidate,"status",""));
summary.validRefReCount = getStructField(candidate,"validRefReCount",0);
summary.selection = string(getStructField(candidate,"selection",""));
scanResults = getStructField(candidate,"scanResults",[]);
if isempty(scanResults)
    return;
end

top = scanResults(1);
summary.slotOffset = getStructField(top,"slotOffset",NaN);
summary.subcarrierLocation = getStructField(top,"subcarrierLocation",NaN);
summary.relativePowerDb = getStructField(top,"relativePowerDb",NaN);
summary.meanAbsLs = getStructField(top,"meanAbsLs",NaN);
summary.activeSlots = getStructField(top,"activeSlots",[]);
end

function facts = loadCaptureFacts(recovery)
facts = struct();
facts.fPhaseCompMHz = NaN;
facts.ssbScsKHz = NaN;
facts.Lmax = NaN;

if isfield(recovery,"captureFile") && isfile(recovery.captureFile)
    captureFile = recovery.captureFile;
else
    captureFile = "";
end

if strlength(string(captureFile)) == 0 || ~isfile(captureFile)
    return;
end

if strlength(string(captureFile)) > 0 && isfile(captureFile)
    capture = load(captureFile,"fPhaseComp","ssbBlockPattern","L_max");
    if isfield(capture,"fPhaseComp")
        facts.fPhaseCompMHz = capture.fPhaseComp / 1e6;
    end
    if isfield(capture,"ssbBlockPattern")
        facts.ssbScsKHz = blockPatternToScs(capture.ssbBlockPattern);
    end
    if isfield(capture,"L_max")
        facts.Lmax = capture.L_max;
    end
end

if isnan(facts.fPhaseCompMHz) && isfield(recovery,"fPhaseComp")
    facts.fPhaseCompMHz = recovery.fPhaseComp / 1e6;
end
if isnan(facts.Lmax) && isfield(recovery,"refBurst")
    facts.Lmax = recovery.refBurst.L_max;
end
if isnan(facts.ssbScsKHz) && isfield(recovery,"refBurst")
    facts.ssbScsKHz = blockPatternToScs(recovery.refBurst.BlockPattern);
end
end

function scs = blockPatternToScs(blockPattern)
switch string(blockPattern)
    case "Case A"
        scs = 15;
    case {"Case B","Case C"}
        scs = 30;
    case "Case D"
        scs = 120;
    case "Case E"
        scs = 240;
    otherwise
        scs = NaN;
end
end

function du = loadDuFacts(configDir, cellIdentity)
sections = readConfigSections(configDir);

cellPhysical = findFirstRow(sections,"cell-physical-conf-idle",cellIdentity);
cellEntries = findFirstRowExact(sections,"gutran-du-cell/gutran-du-cell-entries",cellIdentity);
ssb = findFirstRow(sections,"ssb-configuration",cellIdentity);
bwpRows = findRows(sections,"bwp-list-dl",cellIdentity);
dlDmrs = findFirstRow(sections,"dl-dmrs-config-idle",cellIdentity);
dlPhysical = findFirstRowExact(sections,"dl-physical-resource-config",cellIdentity);
csiRs = findFirstRow(sections,"csi-rs-config",cellIdentity);
trs = findFirstRow(sections,"trs-config",cellIdentity);
sibInfo = findFirstRow(sections,"sib-info",cellIdentity);
bcch = findFirstRow(sections,"bcch-config",cellIdentity);
tdd = findFirstRowExact(sections,"tdd-config-idle",cellIdentity);
bandInfo = findFirstRow(sections,"nr-frequency-band-info",cellIdentity);

du = struct();
du.cellIdentity = cellIdentity;
du.physicalCellId = str2double(rowValue(cellPhysical,"nr-physical-cell-id"));
du.dlArfcn = str2double(rowValue(cellPhysical,"nr-arfcn-dl"));
du.dlCarrierFrequencyMHz = nrArfcnToFrequencyMHz(du.dlArfcn);
du.dlBandwidthMHz = parseFirstNumber(rowValue(cellPhysical,"nr-bandwidth-dl"));
du.band = str2double(rowValue(bandInfo,"nr-frequency-band"));

du.dlScsKHz = parseFirstNumber(rowValue(cellEntries,"dl-subcarrier-spacing"));
du.commonScsText = rowValue(cellEntries,"subcarrier-spacing-common");
du.operationalState = rowValue(cellEntries,"operational-state");
du.activationState = rowValue(cellEntries,"activation-state");

du.ssbScsKHz = parseFirstNumber(rowValue(ssb,"ssb-subcarrier-spacing"));
du.maxNrOfSsb = parseMaxNrOfSsb(rowValue(ssb,"max-nr-of-ssb"));
du.ssbPosition = rowValue(ssb,"ssb-position");
du.ssbPeriodicity = rowValue(ssb,"ssb-periodicity");
du.ssbArfcn = str2double(rowValue(ssb,"ssb-loc-arfcn"));
du.ssbFrequencyMHz = nrArfcnToFrequencyMHz(du.ssbArfcn);
du.rmsiCoresetIndex = str2double(rowValue(ssb,"rmsi-coreset-index"));

du.bwpSummary = summarizeBwpRows(bwpRows);
du.nSizeGrid = bandwidthToNSizeGrid(du.dlBandwidthMHz,du.dlScsKHz);
du.nStartGrid = 0;

du.dmrsTypeAPosition = parseFirstNumber(rowValue(dlDmrs,"dmrs-type-a-position"));
du.dmrsConfigTypeText = rowValue(dlDmrs,"dmrs-type");
du.dmrsAdditionalPositionText = rowValue(dlDmrs,"dmrs-additional-position");
du.dlAntennaCount = rowValue(dlPhysical,"dl-antenna-count");

du.csiRsPeriodicity = rowValue(csiRs,"csi-rs-periodicity");
du.csiRsPowerOffset = rowValue(csiRs,"csi-rs-power-control-offset");
du.trsPeriodicity = rowValue(trs,"trs-periodicity");
du.trsSymbolLocation = rowValue(trs,"trs-symbol-location");
du.trsFreqSeparation = rowValue(trs,"trs-freq-separation");
du.csiRsPeriodicitySlots = parseFirstNumber(du.csiRsPeriodicity);
du.csiRsPowerOffsetDb = parseFirstNumber(du.csiRsPowerOffset);
du.trsPeriodicitySlots = parseFirstNumber(du.trsPeriodicity);
du.trsSymbolLocations = parseIntegerList(du.trsSymbolLocation);
du.trsFreqSeparationValue = parseFirstNumber(du.trsFreqSeparation);

du.sib1Broadcast = rowValue(sibInfo,"sib1-broadcast");
du.siWindowLength = rowValue(sibInfo,"si-window-length");
du.sib1Repetition = rowValue(bcch,"sib1-repetition-period");
du.tddConfigBasic = rowValue(tdd,"tdd-config-basic");
du.nrTddCellConfig = rowValue(tdd,"nr-tdd-cell-config");

du.sources = struct();
du.sources.cellPhysical = rowSource(cellPhysical);
du.sources.cellEntries = rowSource(cellEntries);
du.sources.ssb = rowSource(ssb);
du.sources.bwp = "bwp-list-dl.csv";
du.sources.dlDmrs = rowSource(dlDmrs);
du.sources.csiRs = rowSource(csiRs);
du.sources.trs = rowSource(trs);
du.sources.sibInfo = rowSource(sibInfo);
du.sources.bcch = rowSource(bcch);
du.sources.tdd = rowSource(tdd);
end

function summary = summarizeBwpRows(rows)
summary = strings(0,1);
for idx = 1:numel(rows)
    purpose = rowValue(rows(idx),"bwp-purpose-dl");
    bwSize = rowValue(rows(idx),"bwp-bw-size-dl");
    numRbOffset = rowValue(rows(idx),"bwp-numrb-offset-dl");
    startRbOffset = rowValue(rows(idx),"bwp-startrb-offset-dl");
    summary(end+1,1) = purpose + ": " + bwSize + ", numRB offset " + numRbOffset + ...
        ", startRB offset " + startRbOffset; %#ok<AGROW>
end
end

function sections = readConfigSections(configDir)
listing = dir(fullfile(configDir,"*.csv"));
sections = struct("file",{}, "headers",{}, "rows",{});
for fileIdx = 1:numel(listing)
    filePath = fullfile(listing(fileIdx).folder,listing(fileIdx).name);
    sections = [sections readCsvSections(filePath)]; %#ok<AGROW>
end
end

function sections = readCsvSections(filePath)
lines = readlines(filePath);
sections = struct("file",{}, "headers",{}, "rows",{});
headers = strings(0,1);
rows = {};

for lineIdx = 1:numel(lines)
    line = strip(erase(lines(lineIdx),char(65279)));
    if strlength(line) == 0
        continue;
    end
    fields = parseCsvLine(line);
    if isempty(fields)
        continue;
    end
    if fields(1) == "Node Path"
        if ~isempty(headers)
            sections(end+1) = makeSection(filePath,headers,rows); %#ok<AGROW>
        end
        headers = fields;
        rows = {};
    else
        rows{end+1} = fields; %#ok<AGROW>
    end
end

if ~isempty(headers)
    sections(end+1) = makeSection(filePath,headers,rows);
end
end

function fields = parseCsvLine(line)
line = strip(line);
if strlength(line) == 0
    fields = strings(0,1);
    return;
end
if startsWith(line,'"')
    line = extractAfter(line,1);
end
if endsWith(line,'"')
    line = extractBefore(line,strlength(line));
end
fields = split(line,'","').';
end

function section = makeSection(filePath, headers, rows)
section = struct();
section.file = string(filePath);
section.headers = headers;
section.rows = rows;
end

function row = findFirstRow(sections, pathContains, cellIdentity)
rows = findRows(sections,pathContains,cellIdentity);
if isempty(rows)
    error("run3_validate_recovery_against_du_config:MissingCsvRow", ...
        "Could not find DU CSV row containing path '%s' for cell %d.",pathContains,cellIdentity);
end
row = rows(1);
end

function row = findFirstRowExact(sections, pathSuffix, cellIdentity)
rows = findRowsExact(sections,pathSuffix,cellIdentity);
if isempty(rows)
    error("run3_validate_recovery_against_du_config:MissingCsvRow", ...
        "Could not find DU CSV row ending with path '%s' for cell %d.",pathSuffix,cellIdentity);
end
row = rows(1);
end

function matches = findRows(sections, pathContains, cellIdentity)
matches = struct("file",{}, "headers",{}, "values",{});
for sectionIdx = 1:numel(sections)
    section = sections(sectionIdx);
    for rowIdx = 1:numel(section.rows)
        values = section.rows{rowIdx};
        if isempty(values)
            continue;
        end
        nodePath = values(1);
        if ~contains(nodePath,pathContains)
            continue;
        end
        row = struct("file",section.file,"headers",section.headers,"values",values);
        cellValue = rowValue(row,"cell-identity");
        if strlength(cellValue) == 0 || str2double(cellValue) == cellIdentity
            matches(end+1) = row; %#ok<AGROW>
        end
    end
end
end

function matches = findRowsExact(sections, pathSuffix, cellIdentity)
matches = struct("file",{}, "headers",{}, "values",{});
for sectionIdx = 1:numel(sections)
    section = sections(sectionIdx);
    for rowIdx = 1:numel(section.rows)
        values = section.rows{rowIdx};
        if isempty(values)
            continue;
        end
        nodePath = values(1);
        if ~endsWith(nodePath,pathSuffix)
            continue;
        end
        row = struct("file",section.file,"headers",section.headers,"values",values);
        cellValue = rowValue(row,"cell-identity");
        if strlength(cellValue) == 0 || str2double(cellValue) == cellIdentity
            matches(end+1) = row; %#ok<AGROW>
        end
    end
end
end

function value = rowValue(row, headerName)
value = "";
if isempty(row) || ~isfield(row,"headers")
    return;
end
idx = find(row.headers == string(headerName),1);
if isempty(idx) || idx > numel(row.values)
    return;
end
value = row.values(idx);
end

function source = rowSource(row)
if isempty(row) || ~isfield(row,"file")
    source = "";
    return;
end
[~,name,ext] = fileparts(row.file);
source = string(name + ext);
nodePath = rowValue(row,"Node Path");
if strlength(nodePath) > 0
    source = source + ":" + shortNodePath(nodePath);
end
end

function shortName = shortNodePath(nodePath)
parts = split(string(nodePath),"/");
parts = parts(strlength(parts) > 0);
if isempty(parts)
    shortName = "";
else
    shortName = parts(end);
end
end

function value = parseFirstNumber(textValue)
token = regexp(char(textValue),'\d+','match','once');
if isempty(token)
    value = NaN;
else
    value = str2double(token);
end
end

function values = parseIntegerList(textValue)
tokens = regexp(char(textValue),'\d+','match');
if isempty(tokens)
    values = [];
    return;
end
values = str2double(tokens);
end

function value = parseMaxNrOfSsb(textValue)
textValue = string(textValue);
if contains(textValue,"eight")
    value = 8;
elseif contains(textValue,"four")
    value = 4;
elseif contains(textValue,"sixtyfour") || contains(textValue,"64")
    value = 64;
else
    value = parseFirstNumber(textValue);
end
end

function nSizeGrid = bandwidthToNSizeGrid(bandwidthMHz, scsKHz)
if bandwidthMHz == 100 && scsKHz == 30
    nSizeGrid = 273;
else
    nSizeGrid = NaN;
end
end

function freqMHz = nrArfcnToFrequencyMHz(nRef)
if nRef < 600000
    freqMHz = 0.005 * nRef;
elseif nRef < 2016667
    freqMHz = 3000 + 0.015 * (nRef - 600000);
else
    freqMHz = 24250.08 + 0.06 * (nRef - 2016667);
end
end

function checks = emptyCheckArray()
checks = struct("Status",{}, "Check",{}, "Expected",{}, "Actual",{}, "Source",{}, "Note",{});
end

function checks = addCheck(checks, checkName, expected, actual, pass, source, note)
if pass
    status = "PASS";
else
    status = "FAIL";
end
checks(end+1) = makeCheck(status,checkName,expected,actual,source,note);
end

function checks = addInfo(checks, checkName, expected, actual, source)
checks(end+1) = makeCheck("INFO",checkName,expected,actual,source,"");
end

function check = makeCheck(status, checkName, expected, actual, source, note)
check = struct();
check.Status = string(status);
check.Check = string(checkName);
check.Expected = valueToString(expected);
check.Actual = valueToString(actual);
check.Source = string(source);
check.Note = string(note);
end

function text = valueToString(value)
if isstring(value)
    if numel(value) == 0
        text = "";
    else
        text = join(value(:).',"; ");
    end
elseif ischar(value)
    text = string(value);
elseif isnumeric(value) || islogical(value)
    if isscalar(value)
        if islogical(value)
            text = string(double(value));
        elseif isnan(double(value))
            text = "NaN";
        else
            text = string(value);
        end
    else
        text = mat2str(value);
    end
else
    text = string(evalc("disp(value)"));
    text = strip(text);
end
end

function value = getStructField(s, fieldName, defaultValue)
value = defaultValue;
if isstruct(s) && isfield(s,fieldName)
    value = s.(fieldName);
end
end

function summary = summarizeChecks(validationTable)
summary = struct();
summary.pass = sum(validationTable.Status == "PASS");
summary.fail = sum(validationTable.Status == "FAIL");
summary.info = sum(validationTable.Status == "INFO");
end

function printValidation(validation)
fprintf("=== DU Config Validation ===\n");
fprintf("Recovery file: %s\n",validation.recoveryFile);
fprintf("Config dir: %s\n",validation.configDir);
fprintf("Cell identity: %d\n",validation.cellIdentity);
fprintf("PASS: %d, FAIL: %d, INFO: %d\n\n", ...
    validation.summary.pass,validation.summary.fail,validation.summary.info);

disp(validation.table(:,["Status","Check","Expected","Actual"]));
printCsirsCandidateSummary(validation.csirsCandidateSummary);

if validation.summary.fail > 0
    fprintf("\nFailed checks:\n");
    failed = validation.table(validation.table.Status == "FAIL",:);
    disp(failed(:,["Check","Expected","Actual","Source","Note"]));
end
end

function printCsirsCandidateSummary(summary)
fprintf("\n=== CSI-RS Candidate Scan Summary ===\n");
if ~summary.available
    fprintf("No recovery.csi.csirsCandidate found.\n");
    return;
end

fprintf("Status: %s\n",summary.status);
fprintf("Refs: %d\n",summary.validRefReCount);
fprintf("Best candidate: slotOffset=%s, subcarrierLocation=%s\n", ...
    valueToString(summary.slotOffset),valueToString(summary.subcarrierLocation));
fprintf("Score: relativePower=%s dB, meanAbsLs=%s\n", ...
    valueToString(summary.relativePowerDb),valueToString(summary.meanAbsLs));
fprintf("Active slots: %s\n",valueToString(summary.activeSlots));
if strlength(summary.selection) > 0
    fprintf("Selection: %s\n",summary.selection);
end
fprintf("Note: %s\n",summary.note);
end
