--[[---------------------------------------------------------------------------

	This script is an Admin UI that gives the end user a unified experience by
	making it possible for mod authors to write their admin UI as a plugin for
	this script.
	
	More features need to be added, but the basics are there. eg At the moment
	this script only calls initUI and onShowWindow for plugin modules.
	
	First implemented in Mod Loader v1.2.0
	If you use this feature, your modinfo must have the correct version for
	the Mod Loader dependency.

--]]---------------------------------------------------------------------------

-- Include Files
package.path = package.path .. ";data/scripts/lib/?.lua"
require ("utility")
require ("goods")
require ("randomext")

package.path = package.path .. ";data/scripts/modloader/lib/?.lua"
require ("tabletostring")


-- Local variables
local window = nil
local modListBox
local currentModLabel
local modListLastSelectedIndex = -1

local modsList
local currentMod


function getIcon(seed, rarity)
    return "data/textures/icons/beams-aura.png"
end

function interactionPossible(player)
    return true, ""
end

function initUI()

    local res = getResolution()
    local size = vec2(1200, 650)

    local menu = ScriptUI()
    window = menu:createWindow(Rect(res * 0.5 - size * 0.5, res * 0.5 + size * 0.5))

    window.caption = "ModLoader Admin UI"
    window.showCloseButton = 1
    window.moveable = 1
    menu:registerWindow(window, "ModLoader Admin UI");
	
	local pos = Rect(10, 40, 260, size.y-10)
	modListBox = window:createListBox(pos)
	local modListLabel = window:createLabel(vec2(20, 12), "Available Admin Panels", 14)
	
	currentModLabel = window:createLabel(vec2(290, 12), "", 14)
end

function onShowWindow()
    if onClient() then
		invokeServerFunction("getModList")
	end
end

function getModList()
	if onServer() then
		local player = Player(callingPlayer)
		if not player then return end
	
		local _, t = player:invokeFunction("modloader/modloader.lua", "getAdminUIModules")
		modsList = t

		invokeClientFunction(player, "setModList", t)
	end
end

function setModList(t)
	if onClient and t then
		modsList = t
		modListBox:clear()
		for _, mod in pairs(modsList) do
			modListBox:addEntry(mod.name)
		end
	end
end

function updateUI()
	if modListLastSelectedIndex == modListBox.selected then return end
	modListLastSelectedIndex = modListBox.selected
	
	if modListBox.selected < 0 then
		if currentMod then
			currentMod.container:hide()
			currentMod = nil
		end
		return
	end
	
	-- A new mod has been selected so load it's UI module
	local selectedEntry = modListBox:getSelectedEntry()
	for _, mod in pairs(modsList) do
		if string.match(mod.name, selectedEntry) then
			setCurrentMod(mod)			
			return
		end
	end
end

function setCurrentMod(mod)
	if onClient() then
		if currentMod then
			currentMod.container:hide()
		end
		currentMod = mod
		invokeServerFunction("setCurrentModServer", mod.name)
		
		if not mod.object then
			mod.object = require(mod.script)
			mod.container = window:createContainer(Rect(290, 40, window.size.x-310, window.size.y-10))
			if mod.object and mod.object.initUI then
				mod.object.initUI(mod.container)
			end
		end
		if mod.object and mod.object.onShowWindow then
			printlog("<Admin UI> calling module.onShowWindow")
			mod.object.onShowWindow()
			currentModLabel.caption = mod.name
		end
		mod.container:show()
	end
end

function setCurrentModServer(modName)
	for _, mod in pairs(modsList) do
		if mod.name == modName then
			currentMod = mod
			if not mod.object then
				mod.object = require(mod.script)
			end
			return
		end
	end
end


-- This is to prevent errors with UI elements that require a function when something
-- is selected/changed etc but that function isn't being used by this script.
function dummy() end

--[[else 
	-- disableMod is true
function initialize() terminate() end
end
]]












