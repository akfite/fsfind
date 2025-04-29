function [files, info] = fsfind(parent_dir, pattern, opts)
%FSFIND Recursive filesystem search with regular expression support.
%
%   Usage:
%
%       FILES = FSFIND()
%       FILES = FSFIND(PARENT_DIR)
%       FILES = FSFIND(PARENT_DIR, PATTERN)
%       FILES = FSFIND(PARENT_DIR, PATTERN, options...)
%       [FILES, INFO] = FSFIND(_____)
%
%
%   Inputs:
%
%       PARENT_DIR <Nx1 string>
%           - one or more directories to search
%
%       PATTERN <Nx1 string>
%           - regular expressions to match against filenames (see <a href="matlab:doc regexp">regexp</a>)
%           - if an array of strings is provided, FSFIND returns results that match
%             any of the patterns
%           - leave as an empty array ('' or string.empty) to match anything
%
%   Inputs (optional param-value pairs):
%
%       'CaseSensitive' (=true) <1x1 matlab.lang.OnOffSwitchState>
%           - toggles case sensitivity for all pattern matching
%
%       'Depth' (=1) <1x1 integer>
%           - the maximum search depth relative to PARENT_DIR
%           - will be set to max(Depth, numel(DepthwisePattern)+1)
%
%       'DepthwisePattern' (=string.empty) <Nx1 string>
%           - regular expressions to match at each depth of the search; i.e. 
%             DepthwisePattern{k} matches filenames at depth=k
%           - only folders that match this pattern will be searched.  
%             this can significantly reduce the search scope when the Depth
%             is large, which enables crawling through massive filesystems
%           - leave as an empty array to match anything at a particular
%             depth.  e.g. for applying a filter only to the second folder
%             level, we may set this to {'', 'whatever'}.
%
%       'Silent' (=false) <1x1 matlab.lang.OnOffSwitchState>
%           - suppresses all warnings & print statements
%
%       'SkipFolderFcn' (=[]) <1x1 function_handle>
%           - function to check whether a folder should be scanned PRIOR to
%             actually listing the contents of the directory
%           - for example, let's say you want to avoid checking any folders
%             that were modified more than X years ago.  you can implement
%             a function here that checks the date of each folder prior to
%             listing the folder contents, and return true if the folder meets
%             the threshold to skip.
%           - avoid calling dir() on the contents of this folder in your function;
%             the point of this is to conditionally skip the call to dir() for speed
%           - signature: @(folder) <return true if folder should be skipped>
%
%       'StopAtMatch' (=inf) <1x1 numeric>
%           - stop searching after N matches have been found
%           - the number of results returned will be <= N
%
%       'Timeout' (=inf) <1x1 numeric or duration>
%           - stop the search after a time limit and return whatever was found
%             up to that point
%           - seconds if the input is numeric, but duration type also supported
%
%   Outputs:
%
%       FILES <Nx1 string>
%           - the full filepaths that were matched
%
%       INFO <Nx5 table>
%           - a table of metadata similar to what dir() returns (name, filesize, 
%             isdir, date, folder)
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
%   See also: regexp

%   Author:     Austin Fite
%   Contact:    akfite@gmail.com
%   Date:       2024

    arguments
        parent_dir(:,1) string = pwd
        pattern(:,1) string = ".*"
        opts.CaseSensitive(1,1) matlab.lang.OnOffSwitchState = true
        opts.Depth(1,1) double {mustBePositive} = 1
        opts.DepthwisePattern(:,1) string = string.empty
        opts.Silent(1,1) matlab.lang.OnOffSwitchState = false
        opts.SkipFolderFcn function_handle = function_handle.empty
        opts.StopAtMatch(1,1) double {mustBePositive} = inf
        opts.Timeout(1,1) = inf % numeric or duration
    end

    % depth must at least match the size of the guided search
    opts.Depth = max(opts.Depth, numel(opts.DepthwisePattern)+1);

    if isa(opts.Timeout,'duration')
        opts.Timeout = seconds(opts.Timeout);
    end

    files = string.empty;
    filenames = string.empty;
    isdir = logical.empty;
    sizes = uint64.empty;
    dates = string.empty;

    match_count = 0;

    clock = tic;

    % start searching directories
    for i = 1:numel(parent_dir)
        if ~exist(parent_dir{i},'dir')
            if ~opts.Silent
                warning('fsfind:not_dir', '%s is not a directory; skipping...', parent_dir{i});
            end
            continue
        end

        [fp, fn, dirflag, sz, datemod, match_count] = search(parent_dir{i}, pattern, ...
            opts, ...
            match_count, ...
            clock);

        % accumulate results
        files = vertcat(files, fp); %#ok<*AGROW>
        filenames = vertcat(filenames, fn);
        isdir = vertcat(isdir, dirflag);
        sizes = vertcat(sizes, sz);
        dates = vertcat(dates, datemod);

        % if user requests we stop at N, never return more than N matches
        if numel(files) > opts.StopAtMatch
            N = floor(opts.StopAtMatch);

            files = files(1:N);
            filenames = filenames(1:N);
            isdir = isdir(1:N);
            sizes = sizes(1:N);
            dates = dates(1:N);
        end
        
        if numel(files) == opts.StopAtMatch || toc(clock) > opts.Timeout
            break
        end
    end

    if nargout > 1
        info = table();
        info.name = filenames;
        info.bytes = double(sizes);
        info.isdir = isdir;
        info.date = datetime(dates);
        info.folder = fileparts(files);
    end

end

function [all_filepaths, all_filenames, all_dirflag, all_size, all_dates, match_count] = search(...
    folder, pattern, opts, match_count, clock)
    %SEARCH Recursively search subfolders (but without recursion).

    separator = string(filesep);

    % remove trailing fileseps
    while strcmp(folder(end), separator)
        folder(end) = [];
    end

    all_filenames = string.empty;
    all_filepaths = string.empty;
    all_depths = [];
    all_dirflag = logical.empty;
    all_size = uint64.empty;
    all_dates = string.empty;

    % check up front to see if the user defined a pattern, or if we're matching anything
    match_anything = ...
        isempty(pattern) || ...
        (isscalar(pattern) && (isempty(pattern{1}) || strcmp(pattern,'.*')));

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
            is_dir = all_dirflag(i_search);
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

        if ~isempty(opts.SkipFolderFcn) && feval(opts.SkipFolderFcn, folder)
            i_search = i_search + 1; continue
        end

        if toc(clock) > opts.Timeout
            if ~opts.Silent
                fprintf('[fsfind] timed out (%s, stopped at: %s)\n', ...
                    seconds(toc(clock)), ...
                    folder);
            end
            break
        end
        
        % get all of the contents of this folder (files, dirs, links, etc)
        try
            [filepaths, filenames, dirflag, file_size, dates] = listfiles(folder);
        catch me
            if ~opts.Silent
                fprintf('[fsfind] error: %s\n', folder);
            end
            i_search = i_search + 1; continue
        end
        
        if isempty(filenames)
            i_search = i_search + 1; continue
        end

        file_depth = repmat(depth, numel(filenames), 1);

        % apply depthwise regex pattern to filter matches
        if numel(opts.DepthwisePattern) >= depth ...
                && ~strcmp(opts.DepthwisePattern{depth}, '.*') ...
                && ~isempty(opts.DepthwisePattern{depth})

            mask = ~cellfun('isempty', ...
                regexp(filenames, opts.DepthwisePattern{depth}, ...
                    'once', ...
                    caseopt{:}, ...
                    'forceCellOutput'));

            filenames = filenames(mask);
            filepaths = filepaths(mask);
            file_depth = file_depth(mask);
            dirflag = dirflag(mask);
            file_size = file_size(mask);
            dates = dates(mask);
        end

        % if we have the option to return early, we must match as we search
        if ~isinf(opts.StopAtMatch)
            if match_anything
                pattern_match_mask = true(size(filenames));
            else
                pattern_match_mask = false(size(filenames));
                for i = 1:numel(pattern)
                    pattern_match_mask = pattern_match_mask | ~cellfun('isempty', ...
                        regexp(filenames, pattern{i}, ...
                        'once', ...
                        caseopt{:}, ...
                        'forceCellOutput'));
                end
            end

            is_match = pattern_match_mask & (file_depth > numel(opts.DepthwisePattern));
            match_count = match_count + sum(is_match);

            % note that we can't accumulate only the matches because it's possible that
            % a non-matching folder could be searched and eventually contain a match in
            % a subfolder.  discarding the top-level folder here would be problematic.
        end

        % accumulate results
        all_filepaths = vertcat(all_filepaths, filepaths);
        all_filenames = vertcat(all_filenames, filenames);
        all_depths = vertcat(all_depths, file_depth);
        all_dirflag = vertcat(all_dirflag, dirflag);
        all_size = vertcat(all_size, file_size);
        all_dates = vertcat(all_dates, dates);

        if match_count >= opts.StopAtMatch
            break
        end
 
        i_search = i_search + 1;
    end

    % // end of search for the current parent_dir

    if isempty(all_filepaths)
        return
    end

    % if we guided the search using a depthwise filter, it should be impossible to
    % return results before the end of the filter.  note that we always expect files
    % to be > N, where N is the number of depthwise filters
    if ~isempty(opts.DepthwisePattern)
        mask = all_depths > numel(opts.DepthwisePattern);

        all_filepaths = all_filepaths(mask);
        all_filenames = all_filenames(mask);
        all_dirflag = all_dirflag(mask);
        all_size = all_size(mask);
        all_dates = all_dates(mask);
    end

    % apply the pattern to filter results by filename
    if ~match_anything
        mask = false(size(all_filenames));

        for i = 1:numel(pattern)
            mask = mask | ~cellfun('isempty', ...
                regexp(all_filenames, pattern{i}, ...
                'once', ...
                caseopt{:}, ...
                'forceCellOutput'));
        end

        all_filepaths = all_filepaths(mask);
        all_filenames = all_filenames(mask);
        all_dirflag = all_dirflag(mask);
        all_size = all_size(mask);
        all_dates = all_dates(mask);
    end

end

function [filepaths, filenames, is_directory, file_size, dates] = listfiles(folder)
%LISTFILES Strip the results from dir() to vectors.

    files = dir(folder);
    assert(~isempty(files), 'Failed to open %s', folder);

    % remove the '.' and '..' folders
    for i = 1:numel(files)
        if strcmp(files(i).name,'.')
            files(i+[0 1]) = [];
            break
        end
    end

    filenames = string({files.name}');
    filepaths = string(folder) + filesep + filenames;
    is_directory = vertcat(files.isdir);
    file_size = vertcat(files.bytes);
    dates = string({files.date}');

end
