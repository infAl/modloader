--[[---------------------------------------------------------------------------

	This script gives modders a way to easily register a UI module for the
	admin panel.
	
	First implemented in Mod Loader v1.2.0
	If you use this feature, your modinfo must have the correct version for
	the Mod Loader dependency.
	
--]]---------------------------------------------------------------------------

-- Local Variables
local externalUIModules = {}


-- API Functions

-----------------------------------------------------------
--	Register an Admin UI module that will be available to server admin and singleplayer
-- @param modName The name of the mod registering the ui panel. This is the string that will display in the listbox
-- @param script The script to add to the ship eg "data/scripts/mods/mymod/myscript.lua"
-- @return 0 if the function call failed, 1 for success
function registerAdminUIModule(modName, script)
	if not modName or not script then return 0 end
	
	local t_script = script
	if string.match(script, ".lua") then
		t_script = string.sub(script, 0, string.len(script)-4)
	end
	
	table.insert(externalUIModules, {["name"] = modName, ["script"] = t_script})
	
	if ModLoader.Config.giveAdminPanelAutomatically then
		registerPlayerShipScript("data/scripts/modloader/lib/adminui.lua", true, true, true)
	end
	
	return 1
end

function getAdminUIModules()
	return externalUIModules
end