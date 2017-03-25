--[[---------------------------------------------------------------------------

	This script allows mods to register a system upgrade and have it added as
	a loot drop to NPCs when the player enters a sector or when entities are
	created in a sector (eg: pirate attack, xsotan attack, faction battle)
	
	First implemented in Mod Loader v1.2.0
	If you use this feature, your modinfo must have the correct version for
	the Mod Loader dependency.
	
--]]---------------------------------------------------------------------------

package.path = package.path .. ";data/scripts/modloader/?.lua"
require("lib/enums")

package.path = package.path .. ";data/scripts/lib/?.lua"
require("randomext")
require("utility")

-- This is the format for the loot
--[[local systemUpgradeLoot =
{
	[1] = {
		npc = NPC.Xsotan,
		class = ShipClass.Cruiser,
		distribution = {},
		chance = 10,
		script = "coolantregulator.lua"
	},
	[2] = {
		npc = NPC.Pirate,
		class = ShipClass.All,
		distribution = {},
		chance = 40,
		script = "coolantregulator.lua"
	}
}]]
local systemUpgradeLoot = {}
local isSectorEnteredCallbackRegistered = false
local isSectorLeftCallbackRegistered = false
local isEntityCreateCallbackRegistered
local sectorTrace = {}
local sectorTraceDepth = 5

-- This is the distribution that will be used if nil is passed in to the register function.
-- If you want to have a higher liklihood of good modules etc, copy this table, make changes
-- and pass it in when you register the loot.
local defaultDistribution =
{
	[5] = 0.1,	-- legendary
	[4] = 1,	-- exotic
	[3] = 8,	-- exceptional
	[2] = 16,	-- rare
	[1] = 32,	-- uncommon
	[0] = 128,	-- common
}

-----------------------------------------------------------
--	Registers system upgrades as loot to be added to NPCs
--	
-- @param script The filename for the system upgrade eg "data/scripts/mods/mymods/myupgrade.lua"
-- @param npc The type of NPC you want. Look in modloader/lib/enums.lua for values eg NPC.Xsotan
-- @param class The class of ship. eg ShipClass.Cruiser  or  ShipClass.Any etc
-- @param chance [1-100] The chance of this loot being added to an NPC
-- @return An integer id for the loot table incase you need to remove it at a certain point mid-session
function registerSystemUpgradeAsLoot(script, npc, class, distribution, chance)
	if not script then return 0 end
	
	printlog("<ModLoader> Registering system upgrade as loot: %s", script)
	
	local t_npc = npc or Ship.Any
	local t_class = class or ShipClass.Any
	local t_distribution = distribution or defaultDistribution
	local t_chance = chance or 30
	local i = #systemUpgradeLoot+1
	
	local t = {["npc"]=t_npc, ["class"]=t_class, ["distribution"]=t_distribution, ["chance"]=t_chance, ["script"]=script}
	--table.insert(systemUpgradeLoot, t)
	systemUpgradeLoot[i] = t
	
	if not isSectorEnteredCallbackRegistered then
		printlog("<ModLoader> Registering onSectorEntered callback for api/loot.lua")
		local player = Player()
		player:registerCallback("onSectorEntered", "onSectorEntered_loot")
		isSectorEnteredCallbackRegistered = true
		player:registerCallback("onSectorLeft", "onSectorLeft_loot")
		isSectorLeftCallbackRegistered = true
		Sector():registerCallback("onEntityCreate", "onEntityCreate_loot")
		isEntityCreateCallbackRegistered = true
	end
	--printlog("<ModLoader:Random Loot> systemUpgradeLoot: %s, index: %i", table.tostring(systemUpgradeLoot), i)
	return i
end

function onSectorLeft_loot(playerIndex, x, y)
	if Player().index ~= playerIndex then return end
	
	if onServer() then
		local sector = Sector()
		sector:unregisterCallback("onEntityCreate", "onEntityCreate_loot")
		isEntityCreateCallbackRegistered = false
	end
end

function onSectorEntered_loot(playerIndex, x, y)
	if Player().index ~= playerIndex then return end
	
	if onServer() then
		Sector():registerCallback("onEntityCreate", "onEntityCreate_loot")
		isEntityCreateCallbackRegistered = true
		
		if sectorTrace[sectorTraceDepth] then
			table.remove(sectorTrace, sectorTraceDepth)
		end
		table.insert(sectorTrace, 1, {x, y})
		for _, s in pairs(sectorTrace) do
			if s.x == x and s.y == y then
				return
			end
		end
		
		local sector = Sector()
		shipsList = {sector:getEntitiesByType(EntityType.Ship)}
		if not shipsList then return end

		for _, ship in pairs(shipsList) do
			addLootToShip(ship)
		end
	end
end

function onEntityCreate_loot(entityIndex)
	if onServer() then
		if Entity(entityIndex).isShip then
			-- For some reason the game doesn't return Entity():getValue("is_pirate") when called
			-- from this function but works fine if we call from a deferredCallback with 1 sec delay
			deferredCallback(1, "deferredEntityCreate_loot", entityIndex)
		end
	end
end

function deferredEntityCreate_loot(entityIndex)
	local entity = Entity(entityIndex)
	addLootToShip(Entity(entityIndex))	
end

function addLootToShip(ship)

	-- Xsotan have value is_xsotan = 1
	-- Pirates have value is_pirate = 1
	-- Defenders have value is_armed = 1
	-- Civilians have value is_civil = 1
	math.randomseed(Sector().seed + ship.index)
	
	local addLoot = false
	for _, loot in pairs(systemUpgradeLoot) do
		addLoot = false
		if math.random(1, 100) < loot.chance then
			if loot.npc == NPC.Xsotan then
				if ship:getValue("is_xsotan") then
					if loot.class == ShipClass.Any then
						addLoot = true
					elseif string.match(string.sub(loot.class, 1, 4), string.sub(ship.title, 1, 4)) then
						-- "Smal", "Unkn",  "Big " The alien attack event just names the ships "Small Unknown Ship" and "Unknown Ship" so it's hard to specifically match them if the mod only wants one size or the other
						addLoot = true
					elseif string.match(loot.class, ship.title) then
						-- eg "Xsotan Cruiser"
						addLoot = true
					end
				end
			elseif loot.npc == NPC.Pirate then
				if ship:getValue("is_pirate") then
					if loot.class == ShipClass.Any then
						addLoot = true
					elseif loot.class == ship.title then
						addLoot = true
					end
				end
			elseif loot.npc == NPC.Military then
				if ship:getValue("is_armed") then
					if loot.class == ShipClass.Any then
						addLoot = true
					elseif string.match(loot.class, ship.title) then
						addLoot = true
					end
				end
			elseif loot.npc == NPC.Civilian then
				if ship:getValue("is_civil") then
					if loot.class == ShipClass.Any then
						addLoot = true
					elseif loot.class == ShipClass.AnyMiner then
						if string.match(ship.title, "Min") then
							--All of the mining ships have "Min" in their title
							addLoot = true
						end
					elseif loot.class == ShipClass.AnyFreighter then
						if string.match(ship.title, ShipClass.Transporter) or
						   string.match(ship.title, ShipClass.Freighter) or
						   string.match(ship.title, ShipClass.Lifter) or
						   string.match(ship.title, ShipClass.Loader) or
						   string.match(ship.title, "Cargo") then
						   addLoot = true
						end					
					elseif loot.class == ShipClass.AnyTrader then
						if string.match(ship.title, ShipClass.Trader) or
							string.match(ship.title, ShipClass.Merchant) or
							string.match(ship.title, ShipClass.Salesman) then
							addLoot = true
						end
					
					elseif string.match(string.sub(loot.class, 1, 4), string.sub(ship.title, 1, 4)) then
						-- Specific mining ship
						-- "Ligh", "Mine",  "Heav"
						addLoot = true
					elseif string.match(loot.class, ship.title) then
						addLoot = true
					end
				end
			elseif loot.npc == NPC.Any then
				if string.match(loot.class, ShipClass.Any) then
					addLoot = true
				end
			else
				-- loot.npc was something unexpected
				printlog("<ModLoader:Random Loot> Unexpected Value for NPC: %i, for script: %s", loot.npc, loot.script)
			end
			if addLoot then
				local rarity = Rarity(getValueFromDistribution(loot.distribution))
				Loot(ship.index):insert(SystemUpgradeTemplate(loot.script, rarity, random():createSeed()))
			end
		end
	end
end

