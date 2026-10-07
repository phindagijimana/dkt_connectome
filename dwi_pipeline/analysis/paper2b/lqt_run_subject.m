function lqt_run_subject(lesion_mni, out_dir, atlas_key)
%LQT_RUN_SUBJECT Paper 2B driver — wrap Griffis LQT batch API.
%
% Configure paths to match your LQT install (see docs/papers/LQT.md).
% This stub documents the contract; replace the body with LQT calls once
% LQT_ROOT is on the MATLAB path.

    if nargin < 3
        atlas_key = 'DKT78';
    end
    if ~isfile(lesion_mni)
        error('lqt_run_subject:MissingLesion', 'Lesion not found: %s', lesion_mni);
    end
    if ~exist(out_dir, 'dir')
        mkdir(out_dir);
    end

    manifest = fullfile(out_dir, 'lqt_run_manifest.json');
    fid = fopen(manifest, 'w');
    fprintf(fid, '{\n  "lesion_mni": "%s",\n  "atlas_key": "%s",\n  "status": "stub_not_configured"\n}\n', ...
        strrep(lesion_mni, '\', '/'), atlas_key);
    fclose(fid);

    error(['lqt_run_subject:ConfigureLQT ', ...
        'Edit lqt_run_subject.m to invoke LQT (Griffis 2021) and write parcel SDC to out_dir. ', ...
        'See dwi_pipeline/docs/papers/LQT.md § Practical steps.']);
end
