# fsfind.m

## Description

**fsfind** is a powerful file searching utility for MATLAB that is built for crawling through massive filesystems.  It also has some notable improvements over the built-in `dir` command:
- results are returned as `string` objects
- the search pattern supports regular expressions
- a regex pattern can be provided for *each depth of the search*, which makes it possible
  to efficiently search very deep directory structures
- the search depth is customizable
- metadata is *optionally* returned as a table

## Getting started

Just clone the repository and run `fsfind` in the command window!  Check out the examples
here and run `help fsfind` in the command window to see all available options.

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

We want to find all `data.csv` files under the file system without wasting time searching the `collect_x` folders.  The brute-force way that searches everything would be:

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

## Metadata

MATLAB's `dir` also returns information about file sizes, date modified, etc.  You can access this information with the output from `fsfind` in `table` form:

```matlab
[~, info] = fsfind('C:\Program Files\VideoLAN', '', Depth=2)
```

```
info = 

                folder                          name               bytes       isdir            date        
    _______________________________    ______________________    __________    _____    ____________________

    "C:\Program Files\VideoLAN"        "VLC"                              0    true     24-Nov-2024 13:36:02
    "C:\Program Files\VideoLAN\VLC"    "AUTHORS.txt"                  20213    false    08-Jun-2024 17:24:24
    "C:\Program Files\VideoLAN\VLC"    "COPYING.txt"                  18431    false    08-Jun-2024 17:24:24
    "C:\Program Files\VideoLAN\VLC"    "Documentation.url"               56    false    24-Nov-2024 13:36:02
    "C:\Program Files\VideoLAN\VLC"    "NEWS.txt"                2.1969e+05    false    08-Jun-2024 17:24:24
    "C:\Program Files\VideoLAN\VLC"    "New_Skins.url"                   65    false    24-Nov-2024 13:36:02
    "C:\Program Files\VideoLAN\VLC"    "README.txt"                    2816    false    08-Jun-2024 17:24:24
    "C:\Program Files\VideoLAN\VLC"    "THANKS.txt"                    5774    false    08-Jun-2024 17:24:24
    "C:\Program Files\VideoLAN\VLC"    "VideoLAN Website.url"            51    false    24-Nov-2024 13:36:02
    "C:\Program Files\VideoLAN\VLC"    "axvlc.dll"                1.351e+06    false    08-Jun-2024 18:30:24
    "C:\Program Files\VideoLAN\VLC"    "hrtfs"                            0    true     24-Nov-2024 13:36:01
    "C:\Program Files\VideoLAN\VLC"    "libvlc.dll"              1.9444e+05    false    08-Jun-2024 18:30:28
    "C:\Program Files\VideoLAN\VLC"    "libvlccore.dll"          2.8108e+06    false    08-Jun-2024 18:30:26
    "C:\Program Files\VideoLAN\VLC"    "locale"                           0    true     24-Nov-2024 13:36:01
    "C:\Program Files\VideoLAN\VLC"    "lua"                              0    true     24-Nov-2024 13:36:01
    "C:\Program Files\VideoLAN\VLC"    "npvlc.dll"               1.1544e+06    false    08-Jun-2024 18:30:28
    "C:\Program Files\VideoLAN\VLC"    "plugins"                          0    true     24-Nov-2024 13:36:02
    "C:\Program Files\VideoLAN\VLC"    "skins"                            0    true     24-Nov-2024 13:36:01
    "C:\Program Files\VideoLAN\VLC"    "uninstall.exe"           2.6455e+05    false    24-Nov-2024 13:36:02
    "C:\Program Files\VideoLAN\VLC"    "uninstall.log"                22193    false    24-Nov-2024 13:36:02
    "C:\Program Files\VideoLAN\VLC"    "vlc-cache-gen.exe"       1.4734e+05    false    08-Jun-2024 18:36:46
    "C:\Program Files\VideoLAN\VLC"    "vlc.exe"                 9.9265e+05    false    08-Jun-2024 18:30:24
```