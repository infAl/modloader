package.path = package.path .. ";data/scripts/mods/?.lua"
package.path = package.path .. ";data/scripts/modloader/?.lua"

-- Globally accessible handle
ModLoader = {}

-- 'Constant' values

-- local variables
local mods = {}

-- Mod info
ModLoader.info = 
{
	name="Simple Mod Loader",
	version={ major=1, minor=1, revision=0 },
	description="Provides an easy way for mods to be added to the game.",
	author="infal",
	website="",
	icon=nil,
	dependency=nil,
	playerScript=nil,
	onInitialize=nil
}
table.insert(mods, ModLoader)

-- Modules
require("lib/tabletostring")
require("lib/scandir")
require("api/goods")


-- Avorion default functions
function initialize()
	
	printlog("<ModLoader> Initializing ModLoader")
	
	-- Scan subdirectories in data/scripts/mods/ for modinfo.lua files
	local baseDirectory = "data/scripts/mods/"
	local directories = scandir(baseDirectory, "directories")
	printlog("<ModLoader> Directories: %s", table.tostring(directories))
	if directories then
		for _, dir in pairs(directories) do
			printlog("<ModLoader> Scanning dir: %s", baseDirectory .. dir)
			local files = scandir(baseDirectory .. dir, "files", "*.lua")
			if files then
				printlog("<ModLoader> Files: %s", table.tostring(files))
				for _, file in pairs(files) do
					if string.match(file, "modinfo.lua") then
						local mod = require(baseDirectory .. dir .. "/" .. string.sub(file, 1, string.len(file)-4))
						if mod.info then
							printlog("<ModLoader> Registering mod: %s", mod.info.name)
							table.insert(mods, mod)
						end
					end
				end
			end
		end
	end

	-- Check dependencies
	for _, mod in pairs(mods) do
		mod.isEnabled = true
		if mod.info.dependency then
		printlog("<ModLoader> Checking dependencies for mod: %s", mod.info.name)
		
		for depName, depVers in pairs(mod.info.dependency) do
			local isMatch = false
			local versionOk = false
			
			for __, modInfo in pairs(mods) do
				if depName == modInfo.info.name then
					isMatch = true
					function version_compare(a, b) return a.major <= b.major and a.minor <= b.minor and a.revision <= b.revision end
					function version_tostring(a) return string.format("v%i.%i.%i", a.major, a.minor, a.revision) end
					
					printlog("<ModLoader> -- Required version of %s: %s", depName, version_tostring(depVers))
					printlog("<ModLoader> -- Actual version of %s: %s", depName, version_tostring(modInfo.info.version))
					if version_compare(depVers, modInfo.info.version) then
						versionOk = true
					end
				end
			end
			if isMatch then
				if versionOk then
					printlog("<ModLoader> %s found correct version of %s", mod.info.name, depName)
				else
					printlog("<ModLoader> %s found an incorrect version of %s and will be disabled", mod.info.name, depName)
					mod.isEnabled = false
				end
			else
				printlog("<ModLoader> %s unable to find dependency %s and will be disabled", mod.info.name, depName)
				printlog("<ModLoader> Is %s installed correctly?", depName)
				mod.isEnabled = false
			end
		end
		end
	end

	-- If a mod defines a value for playerScript, that script will
	-- be attached to the player entity at log in
	for _, mod in pairs(mods) do
		if mod.info.playerScript and mod.isEnabled then
			printlog("<ModLoader> mod:%s, is adding script:%s, to player", mod.info.name, mod.info.playerScript)
			if onClient() then
				invokeServerFunction("addScriptOnce", mod.info.playerScript)
			else
				addScriptOnce(mod.info.playerScript)
			end
		end
	end
	
	-- If a mod defines a function for onInitialize, call the function
	-- This is for mods that have code that only needs to run once
	-- when a player logs in. (which is less likely, but an option)
	for _, mod in pairs(mods) do
		if mod.onInitialize and mod.isEnabled then
			printlog("<ModLoader> Running onInitialize for mod:%s", mod.info.name)
			mod.onInitialize()
		end
	end
	
	printlog("<ModLoader> ModLoader initialize complete")
end


function addScriptOnce(script)
	-- Player[Client] object has no addScriptOnce function,
	-- this must run on the server
	if onServer() then
		Player(callingPlayer):addScriptOnce(script)
	end
end

