classdef fstype < uint8
    %FSTYPE File types based on those defined by std::filesystem::file_type
    
    enumeration
        none        (0)
        not_found   (1)
        file        (2)
        directory   (3)
        symlink     (4) % we follow links, so will never actually find a symlink type
        block       (5)
        character   (6)
        fifo        (7)
        socket      (8)
        unknown     (9)
    end

end
