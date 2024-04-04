function [files, filenames, types] = fsfind(parent_dir, pattern, opts)
%FSFIND Fast recursive filesystem search with regular expression support.
%
%   Usage:
%
%       FILES = FSFIND()
%       FILES = FSFIND(PARENT_DIR)
%       FILES = FSFIND(PARENT_DIR, PATTERN)
%       FILES = FSFIND(PARENT_DIR, PATTERN, options...)
%       [FILES, FILENAMES, TYPES] = FSFIND(_____)
%
%
%   Inputs:
%
%       PARENT_DIR <Nx1 string>
%           - one or more directories to search
%
%       PATTERN <Nx1 string>
%           - text to match against filenames
%           - supports regular expressions
%
%   Inputs (optional param-value pairs):
%
%       'Depth' (=1) <1x1 integer>
%           - the maximum search depth relative to PARENT_DIR
%           - will be set to max(MaxDepth, numel(DepthwisePattern))
%
%       'DepthwisePattern' (=string.empty) <Nx1 string>
%           - text to match at each depth of the search
%           - i.e. DepthwisePattern{k} matches filenames at depth=k
%           - can significantly reduce the search scope when the Depth
%             is large, which enables crawling through massive filesystems
%           - supports regular expressions
%
%       'Canonical' (=false) <1x1 logical>
%           - returns canonical, absolute paths
%           - i.e. an absolute path that has no dot, dot-dot elements or  
%             symbolic links in its generic format representation
%           - if a bad symbolic link is encountered while this option is
%             enabled, it will trigger a warning and prevent any files
%             from being found under the folder containing the bad link
%           - requires MEX compiler be enabled
%
%       'CaseSensitive' (=true) <1x1 logical>
%           - toggles case sensitivity for all pattern matching
%
%   Outputs:
%
%       FILES <Nx1 string>
%           - the full filepaths that were matched
%
%       FILENAMES <Nx1 string>
%           - the names of the files that were matched
%           - equivalent to the following:
%
%               [~, FILENAMES, EXT] = fileparts(FILES)
%               FILENAMES = strcat(FILENAMES, EXT);
%
%       TYPES <Nx1 fstype>
%           - the type of each file returned
%           - this is an enumeration based on std::filesystem::file_type
%
%   Notes:
%
%       This function requires that the supporting function "mex_listfiles"
%       be compiled.  See compile_mex_listfiles.m
%
%   Examples:
%
%       % get all files in the current directory
%       files = fsfind()
%       files = fsfind(pwd)
%
%       % get all .m files up to 2 levels deep from current directory
%       files = fsfind(pwd, "\.m$", 'Depth', 2)
%
%   See also: regexp, compile_mex_listfiles

%   Author:     Austin Fite
%   Contact:    akfite@gmail.com
%   Date:       2024

    arguments
        parent_dir(:,1) string = pwd
        pattern(1,1) string = ".*"
        opts.Depth(1,1) double = 1
        opts.DepthwisePattern(:,1) string = string.empty
        opts.Canonical(1,1) logical = false
        opts.CaseSensitive(1,1) logical = true
    end

    persistent is_compiled; % cleared when compile_mex_listfiles is called
    if isempty(is_compiled)
        is_compiled = exist(['mex_listfiles.' mexext],'file') > 0;
        
        if ~is_compiled
            is_compiled = configure_mex();
        end
    end

    if opts.Canonical
        assert(is_compiled, 'fsfind:not_compiled', ...
            ['Canonical paths requires the support function "mex_listfiles" be ' ...
            'compiled.  Run "compile_mex_listfiles()" to resolve this error.']);
    end

    % depth must at least match the size of the guided search
    opts.Depth = max(opts.Depth, numel(opts.DepthwisePattern));

    files = string.empty;
    filenames = string.empty;
    types = fstype.empty;

    for i = 1:numel(parent_dir)
        if ~exist(parent_dir{i},'dir')
            warning('fsfind:not_dir', '%s is not a directory; skipping...', parent_dir{i});
            continue
        end

        [fp, fn, type] = search(parent_dir{i}, pattern, opts);

        files = vertcat(files, fp); %#ok<*AGROW>

        if nargout > 1
            filenames = vertcat(filenames, fn);
        end
        if nargout > 2
            types = vertcat(types, fstype(type));
        end
    end

end

function [all_filepaths, all_filenames, all_type] = search(folder, pattern, opts)

    separator = string(filesep);

    % remove trailing fileseps
    while strcmp(folder(end), separator)
        folder(end) = [];
    end

    all_filenames = string.empty;
    all_filepaths = string.empty;
    all_depths = [];
    all_type = uint8.empty;

    % work with integers for speed (it makes a significant difference here)
    dir_type = uint8(fstype.directory);

    if opts.CaseSensitive
        caseopt = {};
    else
        caseopt = {'ignorecase'};
    end

    i_search = 0;
    depth = 1;

    % start searching through folders
    while i_search <= numel(all_filepaths)
        if i_search > 0
            folder = all_filepaths{i_search};
            is_dir = all_type(i_search) == dir_type;
            depth = all_depths(i_search) + 1;
        else
            is_dir = true;
        end

        if depth > opts.Depth
            i_search = i_search + 1; continue
        end

        if ~is_dir
            i_search = i_search + 1; continue
        end
        
        % get all of the contents of this folder (files, dirs, links, etc)
        try
            [filepaths, filenames, type] = mex_listfiles(folder, opts.Canonical);
        catch me
            warning(me.identifier, ...
                '%s\nThis will prevent finding any results under %s', ...
                me.message, folder);

            i_search = i_search + 1; continue
        end

        file_depth = repmat(depth, numel(filenames), 1);

        if isempty(filenames)
            i_search = i_search + 1; continue
        end

        % apply depthwise regex pattern to filter matches
        if numel(opts.DepthwisePattern) >= depth && ~strcmp(opts.DepthwisePattern{depth}, '.*')
            mask = ~cellfun('isempty', ...
                regexp(filenames, opts.DepthwisePattern{depth}, ...
                'once', ...
                caseopt{:}, ...
                'forceCellOutput'));

            filenames = filenames(mask);
            filepaths = filepaths(mask);
            file_depth = file_depth(mask);
            type = type(mask);
        end

        % accumulate results
        all_filepaths = vertcat(all_filepaths, filepaths);
        all_filenames = vertcat(all_filenames, filenames);
        all_depths = vertcat(all_depths, file_depth);
        all_type = vertcat(all_type, type);
 
        i_search = i_search + 1;
    end

    % // end of search for the current parent_dir

    if isempty(all_filepaths)
        return
    end

    % if we guided the search using a depthwise filter, it should be impossible to
    % return results before the end of the filter
    if ~isempty(opts.DepthwisePattern)
        mask = all_depths >= length(opts.DepthwisePattern);

        all_filepaths = all_filepaths(mask);
        all_filenames = all_filenames(mask);
        all_type = all_type(mask);
    end

    % apply the pattern to filter results by filename
    if ~strcmp(pattern, ".*")
        mask = ~cellfun('isempty', ...
            regexp(all_filenames, pattern, ...
                'once', ...
                caseopt{:}, ...
                'forceCellOutput'));

        all_filepaths = all_filepaths(mask);
        all_filenames = all_filenames(mask);
        all_type = all_type(mask);
    end
end

function is_compiled = configure_mex()
%CONFIGURE_MEX Attempt to compile the support function mex_listfiles.cpp

    is_compiled = false;
    mex_cfg = mex.getCompilerConfigurations('C++');

    if isempty(mex_cfg)
        warning('fsfind:no_mex_compiler', ...
            ['No MEX compiler for C++ has been configured.  ' ...
            'fsfind will have MEX codepaths disabled.  Run "mex -setup -v C++" to resolve.']);
    else
        fprintf(...
            'fsfind: building MEX support function (running compile_mex_listfiles())\n');

        % make sure the supporting mex code is on the path
        if exist('compile_mex_listfiles.m','file') ~= 2
            fsroot = fileparts(mfilename('fullpath'));
            mexroot = fullfile(fsroot, 'mex');

            if exist(mexroot,'dir') == 7
                fprintf('fsfind: adding to path: %s\n', mexroot);
                addpath(genpath(mexroot));
            end
        end

        % attempt to compile supporting MEX
        [is_compiled, msg] = compile_mex_listfiles();

        if is_compiled
            fprintf('fsfind: first-time setup complete!\n');
        else
            fprintf(['fsfind: failed to compile; details below:' ...
                '\n*****************************' ...
                '\n%s' ...
                '\n*****************************\n'], msg);
        end
    end
end
