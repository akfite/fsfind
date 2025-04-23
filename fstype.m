classdef fstype < uint8
    %FSTYPE File types based on those defined by std::filesystem::file_type
    
    enumeration
        none        (0)
        not_found   (1)
        file        (2)
        directory   (3)
        % symlink -- not included because we follow links, so will never find symlinks
        block       (5)
        character   (6)
        fifo        (7)
        socket      (8)
        unknown     (9)
    end

end
