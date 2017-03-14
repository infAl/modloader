
local modgoods = {}

function getGoodsTable()
	-- A mod has requested a table containing the modded goods.
	--printlog("<ModLoader> Replying to request for goods list: %s", table.tostring(goods))
	return modgoods
end

function registerGoods(newgoods)
	-- A mod is adding new goods to the game
	--printlog("<ModLoader> Registering goods: %s", table.tostring(newgoods))
	if newgoods then
		for name, good in pairs(newgoods) do
			modgoods[name] = good
		end
	end
end
