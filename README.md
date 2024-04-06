# fsfind.m

## Description

**fsfind** is a powerful file searching utility for MATLAB.  It has some notable improvements
over the built-in `dir` command:
- results are returned as `string` objects
- the search depth is customizable
- the search pattern supports regular expressions
- a regex pattern can be provided for *each depth of the search*, which makes it possible
  to efficiently search very deep directory structures
- C++ MEX back-end allows it to be even faster than `dir` (in some cases)

## Getting started

Just clone the repository and run `fsfind` in the command window!  If you are on a UNIX machine,
it will compile the MEX code prior to running the search.  If you are on Windows, it will default
to the non-MEX path (for some reason, the MEX version is slower on Windows).  If you ever wish
to override this and use the MEX version, you can call `compile_mex_listfiles()` to build
the supporting MEX function.  The correct code path will be selected inside `fsfind`.

## Example usage

Find all files in the current directory:
```
files = fsfind()
```

Find all `.m` files (recursively) under the current directory:
```
files = fsfind(pwd, '\.m$', 'Depth', inf)
```

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

We want to find all `data.csv` files under the file system.  The brute-force way would be:

```
files = fsfind(root, 'data\.csv', 'Depth', inf)
```

However, if we know that this directory structure will be consistent, we can optimize the
search by supplying a filter at each depth level like so:

```
files = fsfind(root, 'data\.csv', 'DepthwisePattern', {'dataset-\d+', 'results'})
```

This way, the search does not go inside each `collect_` folder because the `DepthwisePattern`
only includes matches against the `results` folder at the second depth level.  Note that each
pattern only needs to partially match--so in this example, `dataset-\d+` could just as well be
`dataset` and we would get the same result.  Also, since we did not specify `Depth` but we did
specify the `DepthwisePattern`, the `Depth` defaulted to one more than the length of the filter--
in this case, `3`.

This concept is powerful for large filesystems.  You can design fast searches on directories 10+ 
levels deep that would otherwise take ages using something like `dir(**/*.m)`.

