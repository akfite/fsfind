# fsfind.m

## Description

**fsfind** is a powerful file searching utility for MATLAB that is built for crawling through massive filesystems.  It also has some notable improvements over the built-in `dir` command:
- results are returned as `string` objects
- the search pattern supports regular expressions
- a regex pattern can be provided for *each depth of the search*, which makes it possible
  to efficiently search very deep directory structures
- the search depth is customizable
- C++ MEX back-end allows it to be even faster than `dir` (but will fall back to dir() if user cannot compile)

## Getting started

Just clone the repository and run `fsfind` in the command window!  If you are on a UNIX machine,
it will compile the MEX code prior to running the search.  If you are on Windows, it will default
to the non-MEX path (for some reason, the MEX version is slower on Windows).  If you ever wish
to override this and use the MEX version, you can call `compile_mex_listfiles()` to build
the supporting MEX function.  The correct code path will be selected inside `fsfind`.

## Examples

### Find all files in the current directory:
```matlab
files = fsfind()
```

### Find all `.m` files (recursively) under the current directory:
```matlab
files = fsfind(pwd, '\.m$', Depth=inf)
```

### Search a structured folder hierarchy
Assume we have a directory structure of the following form:
* `root`
    * `dataset-1`
        * `collect_1`
        * `collect_2`
        * ...
        * `results`
            * `data.csv`
    * `dataset-2`
        * `collect_1`
        * `collect_2`
        * ...
        * `results`
            * `data.csv`
    * `dataset-3`
        * ...
    * `other-junk`

We want to find all `data.csv` files under the file system without wasting time searching the `dataset-x` folders.  The brute-force way that searches everything would be:

```matlab
files = fsfind(root, 'data\.csv', Depth=inf)
```
or, using built-in MATLAB:
```matlab
files = dir('**/data.csv');
```

However, if we know that this directory structure will be consistent, we can optimize the
search with `fsfind` by supplying a filter at each depth level like so:

```matlab
files = fsfind(root, 'data\.csv', DepthwisePattern={'dataset-\d+', 'results'})
```

This way, the search does not go inside each `collect_` folder because the `DepthwisePattern`
only includes matches against the `results` folder at the second depth level.  Note that each
pattern only needs to partially match--so in this example, `dataset-\d+` could just as well be
`dataset` and we would get the same result.  Also, since we did not specify `Depth` but we did
specify the `DepthwisePattern`, the `Depth` defaulted to one more than the length of the filter--
in this case, `3`.

This concept is powerful for large filesystems.  You can design fast searches on deeply-nested directories with  thousands of files that would otherwise take ages using something like `dir(**/*)`.

