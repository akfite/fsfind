//   Description: MEX implementation of listing files in a folder & is_dir flag
//
//   Author:     Austin Fite
//   Contact:    akfite@gmail.com
//   Date:       2024

#include <filesystem>
#include <list>
#include <string>

// mex includes
#include "mex.h"
#include "matrix.h"

using namespace std::filesystem;

// lightweight replacement for MATLAB's "dir"
inline std::list<path> get_contents(std::string folder)
{
    std::list<path> files;
    for (const auto& entry : directory_iterator(folder))
    {
        files.emplace_back(entry.path());
    }
    return files;
}

// MATLAB gateway 
void mexFunction(int nargout, mxArray *outputs[], int nargin, const mxArray *inputs[])
{
    if (nargin != 2)
    {
        mexErrMsgTxt("Incorrect number of input arguments (expected 2).");
        // exit
    }

    if (nargout > 3)
    {
        mexErrMsgTxt("Incorrect number of output arguments (expected <= 3).");
        // exit
    }
    
    if (!mxIsChar(inputs[0]))
    {
        mexErrMsgTxt("The input folder must be a character vector.");
    }

    const std::string folder = std::string(mxArrayToString(inputs[0]));
    const bool make_canonical = *mxGetLogicals(inputs[1]);
    
    // list everything in current folder
    const std::list<path> paths = get_contents(folder);

    // place filepaths & names into a cell array for output
    const mwSize N = paths.size();
    mxArray* out_filepaths = mxCreateCellMatrix(N, 1);
    mxArray* out_filenames = mxCreateCellMatrix(N, 1);
    // output flag for directories
    mxArray* out_isdir = mxCreateLogicalMatrix(N, 1);
    mxLogical* p_out_isdir = mxGetLogicals(out_isdir);

    mwIndex i = 0;

    // copy to outputs
    for (path p : paths)
    {
        if (make_canonical)
            p = std::filesystem::canonical(p);

        const std::string fullpath = p;
        mxSetCell(out_filepaths, i, mxCreateString(fullpath.c_str()));
        mxSetCell(out_filenames, i, mxCreateString(p.filename().c_str()));
        p_out_isdir[i] = is_directory(p);
        i++;
    }

    outputs[0] = out_filepaths;
    outputs[1] = out_filenames;
    outputs[2] = out_isdir;
}
