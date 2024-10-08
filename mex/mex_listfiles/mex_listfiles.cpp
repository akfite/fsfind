//   Description: MEX implementation of listing files in a folder.
//
//   Author:     Austin Fite
//   Contact:    akfite@gmail.com
//   Date:       2024

#include <cstdint>
#include <filesystem>
#include <list>
#include <string>

// mex includes
#include "mex.h"
#include "matrix.h"

namespace fs = std::filesystem;

// lightweight replacement for MATLAB's "dir"
inline std::list<fs::path> get_contents(const std::string& folder)
{
    std::list<fs::path> files;
    for (const auto& entry : fs::directory_iterator(folder))
    {
        files.emplace_back(entry.path());
    }
    return files;
}

inline uint8_t uint8_filetype(const fs::path& p)
{
    auto status = fs::status(p);

    switch (status.type())
    {
        case fs::file_type::regular:
            return 2;
        case fs::file_type::directory:
            return 3;
        case fs::file_type::symlink:
            return 4;
        case fs::file_type::block:
            return 5;
        case fs::file_type::character:
            return 6;
        case fs::file_type::fifo:
            return 7;
        case fs::file_type::socket:
            return 8;
        case fs::file_type::unknown:
            return 9;
        case fs::file_type::none:
            return 0;
        case fs::file_type::not_found:
            return 1;
        default:
            return 9;
    }
}

// MATLAB gateway 
void mexFunction(int nargout, mxArray *outputs[], int nargin, const mxArray *inputs[])
{
    if (nargin != 1)
    {
        mexErrMsgTxt("Incorrect number of input arguments (expected 1).");
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
    
    // list everything in current folder
    const std::list<fs::path> paths = get_contents(folder);

    // place filepaths & names into a cell array for output
    size_t N = paths.size();
    mxArray* out_filepaths = mxCreateCellMatrix(N, 1);
    mxArray* out_filenames = mxCreateCellMatrix(N, 1);
    // outut file type array
    mwSize dims[2] = {N, 1};
    mxArray* out_type = mxCreateNumericArray(2, dims, mxUINT8_CLASS, mxREAL);
    uint8_t* p_out_type = mxGetUint8s(out_type);

    // keep track of numeric index as we range-based loop over paths
    mwIndex i = 0;

    // copy to outputs
    for (fs::path p : paths)
    {
        const std::string fullpath = p.string();
        mxSetCell(out_filepaths, i, mxCreateString(fullpath.c_str()));
        mxSetCell(out_filenames, i, mxCreateString(p.filename().string().c_str()));
        p_out_type[i] = uint8_filetype(p);

        i++;
    }

    outputs[0] = out_filepaths;
    outputs[1] = out_filenames;
    outputs[2] = out_type;
}
