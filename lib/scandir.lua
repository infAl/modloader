package.path = package.path .. ";data/scripts/lib/?.lua"
require("stringutility")

function scandir(directory, task, pattern)

    local i, t, popen = 0, {}, io.popen
	local BinaryFormat = string.sub(package.cpath,-3)
	local cmd = ""
	if not string.ends(directory, "/") then
		directory = directory .. "/"				
	end
	local path = directory	
	if pattern then 	
		path = path .. pattern
	end
    if BinaryFormat == "dll" then
		path = string.gsub(path, "/", "\\")
		if string.match(task, "files") then
			cmd =   'dir "'..path..'" /b /a-d'
		else
			cmd =   'dir "'..path..'" /b /ad'
		end
    else
		path = string.gsub(path, "\\", "/")
		if string.match(task, "files") then
			cmd = "ls " .. path
		else
			cmd = "ls -ld " .. path
		end
    end
    local pfile = popen(cmd)
    for filename in pfile:lines() do
		i = i + 1
		if string.starts(filename, directory) then
			t[i] = string.sub(filename, string.len(directory) + 1)
		else
			t[i] = filename
		end		
    end
    pfile:close()
    return t
	
end