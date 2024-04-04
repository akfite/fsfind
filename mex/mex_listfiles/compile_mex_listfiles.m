function [ok, msg] = compile_mex_listfiles(cmd)
%COMPILE_MEX_LISTFILES Compile the MEX code for fast file listing.
%
%   Usage:
%
%       COMPILE_MEX_LISTFILES()
%       COMPILE_MEX_LISTFILES(CMD)
%
%   Inputs:
%
%       CMD (='build') <1xN char>
%
%           'build'   - runs the mex compiler only if compiled code doesn't exist
%           'clean'   - deletes all compiled code
%           'rebuild' - runs 'clean', followed by 'build'
%
%   See also: fsfind

%   Author:  Austin Fite
%   Date:    2024

    if nargin < 1
        cmd = 'build';
    end

    validatestring(cmd, {'build','rebuild','clean'});

    % will set this flag to false if compilation fails
    ok = true;
    msg = '';

    mexroot = fileparts(mfilename('fullpath'));
    mexfile = ['mex_listfiles.' mexext];
    mexfilepath = fullfile(mexroot, mexfile);

    switch cmd
        case 'build'
            if exist(mexfilepath,'file')
                msg = sprintf('%s exists (skipping)', mexfile);
                return
            end

            try
                orig = cd(mexroot);
                moveback = onCleanup(@() cd(orig));

                % mex configs
                MEXOPTS = {'-R2018a','-O'};

                cfg = mex.getCompilerConfigurations('C++');
                assert(~isempty(cfg), ...
                    'No MEX C++ compiler has been configured (run "mex -setup -v C++")');

                if contains(cfg.ShortName, 'mingw')
                    assert(str2double(cfg.Version(1)) >= 9, ...
                        'MinGW does not support std::filesystem until v9.1+');
                elseif contains(cfg.ShortName,'MSVC')
                    CXXFLAGS = {'COMPFLAGS="/std:c++17"'};
                else
                    CXXFLAGS = {'CXXFLAGS="-std=c++17"'};
                end

                % compile
                mex(MEXOPTS{:}, CXXFLAGS{:}, 'mex_listfiles.cpp');

            catch err
                ok = false;
                msg = err.message;
            end

        case 'rebuild'
            [ok, msg] = compile_mex_listfiles('clean');

            if ~ok
                msg = ['Failed during clean: ' msg];
                return
            end

            [ok, msg] = compile_mex_listfiles('build');

        case 'clean'
            try
                if exist(mexfilepath, 'file')
                    delete(mexfilepath);
                end
            catch err
                ok = false;
                msg = err.message;
            end
    end

    % clear state of caller function that will track compilation status
    clear fsfind;

end
