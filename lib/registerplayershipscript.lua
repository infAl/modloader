--[[---------------------------------------------------------------------------

	This script gives mod authors a way to easily register a script that they
	want to be attached to the player ship.
	
	First implemented in Mod Loader v1.2.0
	If you use this feature, your modinfo must have the correct version for
	the Mod Loader dependency.
	
--]]---------------------------------------------------------------------------


-- Local Variables
local scriptList = {}
local isShipChangedCallbackRegistered = false


-- API Functions

-----------------------------------------------------------
--	Register a script for ModLoader to add to player ships automatically any time
--	the player enters a ship.
-- @param script The script to add to the ship eg "data/scripts/mods/mymod/myscript.lua"
-- @param removeOnExit [true/false] Should the script be removed from the ship when the player exits the ship?
-- @param allowDrone [true/false] Should the script be added to the drone?
-- @param adminOnly [true/false] Is this script only for admins?
-- @return The index of the script in case you need to remove it mid session
function registerPlayerShipScript(script, removeOnExit, allowDrone, adminOnly)
	if not script then return 0 end
	
	-- Check if the script has already been registered
	for i, s in ipairs(scriptList) do
		if s.script == script then return i end
	end
	
	printlog("<ModLoader> Registering player ship script: %s", script)
	
	local t_removeOnExit = removeOnExit
	if t_removeOnExit == nil then t_removeOnExit = true end
	local t_allowDrone = allowDrone
	if t_allowDrone == nil then t_allowDrone = false end
	local t_adminOnly = adminOnly
	if t_adminOnly == nil then t_adminOnly = false end
	
	local i = #scriptList +1
	local t = {["script"]=script, ["removeOnExit"]=t_removeOnExit, ["allowDrone"]=t_allowDrone, ["adminOnly"]=t_adminOnly}
	scriptList[i] = t
	
	if not isShipChangedCallbackRegistered then
		Player():registerCallback("onShipChanged", "onShipChanged_shipchanged")
		Player():registerCallback("onSectorLeft", "onSectorLeft_shipchanged")
		isShipChangedCallbackRegistered = true
	end
	
	return i
end


-- Event Handler Functions
function onSectorLeft_shipchanged(playerIndex, x, y)
	Player(playerIndex):setValue("lastShipIndex_modloader", nil)
end


function onShipChanged_shipchanged(playerIndex, craftIndex)
	if Player().index ~= playerIndex then return end
	if onServer() then
		local player = Player(playerIndex)
		local isPlayerAdmin = Server():hasAdminPrivileges(player)
		local lastShipIndex = player:getValue("lastShipIndex_modloader")
		local lastShip
		if lastShipIndex then
			lastShip = Entity(lastShipIndex)
		end
		local currentShip = Entity(craftIndex)
		local isDrone = player.craft.type == EntityType.Drone
		
		-- Proces each entry in the scriptList table
		for _, t in pairs(scriptList) do
		
			-- Remove script from previous ship if necessary
			if lastShip and t.removeOnExit then
				lastShip:removeScript(t.script)
				--Server():broadcastChatMessage("ModLoader ShipChanged", 0, "Removing script from ship: %i", lastShipIndex)
			end
			
			-- Add Script to current ship
			if not isDrone or t.allowDrone then
				if isPlayerAdmin or not t.adminOnly then
					currentShip:addScriptOnce(t.script)
					--Server():broadcastChatMessage("ModLoader ShipChanged", 0, "Adding script to ship: %i", craftIndex)
				end
			end
		end
		
		-- Store the index of the current ship with the player so we can know which ship
		-- they exited next time they change ships.
		-- If they're in the drone though, set it to nil
		if isDrone then
			player:setValue("lastShipIndex_modloader", nil)
		else
			player:setValue("lastShipIndex_modloader", craftIndex)
		end
	end		
end