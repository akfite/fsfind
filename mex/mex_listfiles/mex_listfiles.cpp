//   Description: MEX implementation of listing files in a folder & is_dir flag
//
//   Author:     Austin Fite
//   Contact:    akfite@gmail.com
//   Date:       2024

#include <filesystem>
#include <list>
#include <string>
#include <tuple>

// mex includes
#include "mex.h"
#include "matrix.h"

using namespace std::filesystem;

// list contents of a folder (without detailed metadata)
inline std::list<std::tuple<std::string, bool>> get_contents(std::string folder)
{
    std::list<std::tuple<std::string, bool>> files;
    for (const auto& entry : directory_iterator(folder))
    {
        const auto p = entry.path();
        const bool is_dir = is_directory(p);

        files.emplace_back(p.filename(), is_dir);
    }
    return files;
}

// MATLAB gateway 
void mexFunction(int nargout, mxArray *outputs[], int nargin, const mxArray *inputs[])
{
    if (nargin != 1)
    {
        mexErrMsgTxt("Incorrect number of input arguments (expected 1).");
        // exit
    }

    if (nargout > 2)
    {
        mexErrMsgTxt("Incorrect number of output arguments (expected <= 2).");
        // exit
    }
    
    if (!mxIsChar(inputs[0]))
    {
        mexErrMsgTxt("The input folder must be a character vector.");
    }

    const std::string folder = std::string(mxArrayToString(inputs[0]));
    
    // search for files
    const std::list<std::tuple<std::string, bool>> contents = get_contents(folder);

    // place files into a cell array for output
    const mwSize N = contents.size();
    mxArray* out_filepaths = mxCreateCellMatrix(N, 1);
    mxArray* out_isdir = mxCreateLogicalMatrix(N, 1);
    mxLogical* p_out_isdir = mxGetLogicals(out_isdir);

    mwIndex i = 0;

    for (const auto& item : contents)
    {
        mxSetCell(out_filepaths, i, mxCreateString(std::get<0>(item).c_str()));
        p_out_isdir[i] = std::get<1>(item);
        i++;
    }

    outputs[0] = out_filepaths;
    outputs[1] = out_isdir;
}
