function [files, filenames] = fsfind(parent_dir, pattern, opts)
%FSFIND Fast recursive filesystem search with regular expression support.
%
%   Usage:
%
%       FILES = FSFIND()
%       FILES = FSFIND(PARENT_DIR)
%       FILES = FSFIND(PARENT_DIR, PATTERN)
%       FILES = FSFIND(PARENT_DIR, PATTERN, options...)
%       [FILES, FILENAMES] = FSFIND(_____)
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
%           - i.e. DepthwisePattern{k} matches at depth=k
%           - can significantly reduce the search scope when the Depth
%             is large, which enables crawling through massive filesystems
%           - supports regular expressions
%
%       'Canonical' (=false) <1x1 logical>
%           - returns canonical, absolute paths
%           - i.e. an absolute path that has no dot, dot-dot elements or  
%             symbolic links in its generic format representation
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
%   Date:       2024

    arguments
        parent_dir(:,1) string = pwd
        pattern(1,1) string = ".*"
        opts.Depth(1,1) double = 1
        opts.DepthwisePattern(:,1) string = string.empty
        opts.Canonical(1,1) logical = false
    end

    persistent use_mex; % cleared when the compile function is called
    if isempty(use_mex)
        use_mex = exist(['mex_listfiles.' mexext],'file') > 0;

        if ~use_mex
            warning('fsfind:not_compiled',...
                ['fsfind is running without MEX support.  ' ...
                'Run "compile_mex_listfiles()" to enable faster code execution.']);
        end
    end

    % depth must at least match the size of the guided search
    opts.Depth = max(opts.Depth, numel(opts.DepthwisePattern));

    files = string.empty;
    filenames = string.empty;

    for i = 1:numel(parent_dir)
        if ~exist(parent_dir{i},'dir')
            warning('fsfind:not_dir', '%s is not a directory; skipping...', parent_dir{i});
            continue
        end

        [fp, fn] = execute_search(parent_dir{i}, pattern, opts, use_mex);

        files = vertcat(files, fp); %#ok<*AGROW>
        filenames = vertcat(filenames, fn);
    end

end

function [all_filepaths, all_filenames] = execute_search(folder, pattern, opts, use_mex)

    separator = string(filesep);

    % remove trailing fileseps
    while strcmp(folder(end), separator)
        folder(end) = [];
    end

    all_filenames = string.empty;
    all_filepaths = string.empty;
    all_depths = [];
    all_is_dir = logical.empty;

    i_search = 0;
    depth = 1;

    % start searching through folders
    while i_search <= numel(all_filepaths)
        if i_search > 0
            folder = all_filepaths{i_search};
            is_dir = all_is_dir(i_search);
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
        
        % get all files & directories in the current folder
        [filepaths, filenames, is_dir] = mex_listfiles(folder, opts.Canonical);
        file_depth = repmat(depth, numel(filenames), 1);

        if isempty(filenames)
            i_search = i_search + 1; continue
        end

        % apply depthwise regex pattern to filter matches
        if numel(opts.DepthwisePattern) >= depth && ~strcmp(opts.DepthwisePattern{depth}, '.*')
            mask = ~cellfun('isempty', ...
                regexp(filenames, opts.DepthwisePattern{depth}, 'once', 'forceCellOutput'));

            filenames = filenames(mask);
            filepaths = filepaths(mask);
            file_depth = file_depth(mask);
            is_dir = is_dir(mask);
        end

        % accumulate results
        all_filepaths = vertcat(all_filepaths, filepaths);
        all_filenames = vertcat(all_filenames, filenames);
        all_depths = vertcat(all_depths, file_depth);
        all_is_dir = vertcat(all_is_dir, is_dir);
 
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
    end

    % apply the pattern to filter results by filename
    if ~strcmp(pattern, ".*")
        mask = ~cellfun('isempty', ...
            regexp(all_filenames, pattern, 'once', 'forceCellOutput'));

        all_filepaths = all_filepaths(mask);
        all_filenames = all_filenames(mask);
    end

end
