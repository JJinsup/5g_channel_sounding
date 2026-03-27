function bucketName = getDurationBucketName(durationMs)
%GETDURATIONBUCKETNAME Build a stable folder name for capture duration.

arguments
    durationMs (1,1) double {mustBePositive}
end

bucketName = sprintf('%gms', durationMs);
bucketName = strrep(bucketName, '.', 'p');
end
