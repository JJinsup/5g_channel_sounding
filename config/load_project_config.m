function cfg = load_project_config(repoRoot, configFile, overrides)
%LOAD_PROJECT_CONFIG Load default config plus an optional hardware profile.

if nargin == 0 || isempty(repoRoot)
    repoRoot = pwd;
end
if nargin < 2
    configFile = "";
end
if nargin < 3
    overrides = struct();
end

profileOverrides = struct();
configFile = string(configFile);
if strlength(configFile) > 0
    configPath = resolveConfigPath(repoRoot,configFile);
    configDir = fileparts(configPath);
    [~,configName] = fileparts(configPath);
    addpath(configDir);
    profileOverrides = feval(configName);
end

cfg = default_config(repoRoot,mergeOverrides(profileOverrides,overrides));
end

function configPath = resolveConfigPath(repoRoot, configFile)
if startsWith(configFile,filesep) && isfile(configFile)
    configPath = char(configFile);
    return;
end

if isfile(configFile)
    configPath = char(fullfile(pwd,configFile));
    return;
end

candidate = fullfile(repoRoot,configFile);
if isfile(candidate)
    configPath = char(candidate);
    return;
end

candidate = fullfile(repoRoot,"config",configFile);
if isfile(candidate)
    configPath = char(candidate);
    return;
end

if ~endsWith(configFile,".m")
    candidate = fullfile(repoRoot,"config",configFile + ".m");
    if isfile(candidate)
        configPath = char(candidate);
        return;
    end

    candidate = fullfile(repoRoot,"config",configFile + "_config.m");
    if isfile(candidate)
        configPath = char(candidate);
        return;
    end
end

error("load_project_config:ConfigNotFound","Config file not found: %s.",configFile);
end

function merged = mergeOverrides(base, override)
merged = base;
if isempty(override)
    return;
end

fields = fieldnames(override);
for idx = 1:numel(fields)
    fieldName = fields{idx};
    overrideValue = override.(fieldName);
    if isstruct(overrideValue) && isfield(merged,fieldName) && isstruct(merged.(fieldName))
        merged.(fieldName) = mergeOverrides(merged.(fieldName),overrideValue);
    else
        merged.(fieldName) = overrideValue;
    end
end
end
