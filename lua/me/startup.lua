local NervConnection = require("../shared/NervConnection")

print("======================================");
print("        _   ____________ _    __      ");
print("       / | / / ____/ __ \\ |  / /      ");
print("      /  |/ / __/ / /_/ / | / /       ");
print("     / /|  / /___/ _, _/| |/ /        ");
print("    /_/ |_/_____/_/ |_| |___/         ");
print("                                      ");
print("======================================");
print("Starting up!")

local me
local connection = NervConnection:new{}

repeat
	me = peripheral.find("meBridge")

	if not me then
		printError("No ME Bridge found. Trying again in 30 seconds.")
		sleep(30)
	end
until me

print("Declaring handlers...")

local function getObjects(--[[optional]] withItems, --[[optional]] withFluid, --[[optional]] withGas)
	if not me.isConnected() then
		error("ME system is unavailable.")
	end

	local objects = {}
	if withItems then
		local items = me.listItems()
		for _, v in ipairs(items) do
			table.insert(objects, v)
		end
	end
	if withFluid then
		local fluids = me.listFluid()
		for _, v in ipairs(fluids) do
			v.amount = v.amount / 1000
			table.insert(objects, v)
		end
	end
	if withGas then
		local gases = me.listGas()
		for _, v in ipairs(gases) do
			v.amount = v.amount / 1000
			table.insert(objects, v)
		end
	end

	return objects
end

-- HANDLER FUNCTIONS

local function _handler_unified(_conn, data, withItems, withFluid, withGas)
	local page = data.page or 0
	local order = data.order or "count-desc"
	local count = data.count or 50
	
	print("Getting ME system inventory...")
	local querySuccess, objects = pcall(getObjects, withItems, withFluid, withGas)
	if not querySuccess then
		return { error = true, message = objects }
	end

	if order == "alpha-asc" then
		table.sort(objects, function (a, b)
			return b.displayName > a.displayName
		end)
	elseif order == "alpha-desc" then
		table.sort(objects, function (a, b)
			return b.displayName < a.displayName
		end)
	elseif order == "count-asc" then
		table.sort(objects, function (a, b)
			return a.amount < b.amount
		end)
	else
		table.sort(objects, function (a, b)
			return b.amount < a.amount
		end)
	end
	
	local toReply = {}
	for i = 1, count, 1 do
		if objects[i + (page * count)] == nil then
			break
		end
		toReply[i] = objects[i + (page * count)]
	end
	
	return { list = toReply }
end

local function handler_getStatus()
	if not me.isConnected() then
		error("ME system is unavailable.")
	end

	return {
		fluidStorage = {
			available = me.getAvailableFluidStorage(),
			total = me.getTotalFluidStorage(),
			used = me.getUsedFluidStorage()
		},
		itemStorage = {
			available = me.getAvailableItemStorage(),
			total = me.getTotalItemStorage(),
			used = me.getUsedItemStorage()
		},
		powerInjection = me.getAvgPowerInjection(),
		powerUsage = me.getAvgPowerUsage(),
		configuration = me.getConfiguration(),
		craftingCPUs = me.getCraftingCPUs(),
		energyStorage = me.getEnergyStorage(),
		maxEnergyStorage = me.getMaxEnergyStorage(),
		energyUsage = me.getEnergyUsage(),
		cells = me.listCells()
	}
end

local function handler_list(_conn, data)
	return _handler_unified(_conn, data, true, true, true)
end
local function handler_listItems(_conn, data)
	return _handler_unified(_conn, data, true, false, false)
end
local function handler_listFluid(_conn, data)
	return _handler_unified(_conn, data, false, true, false)
end
local function handler_listGas(_conn, data)
	return _handler_unified(_conn, data, false, false, true)
end

connection:setHandler("list", handler_list)
connection:setHandler("listItems", handler_listItems)
connection:setHandler("listFluid", handler_listFluid)
connection:setHandler("listGas", handler_listGas)
connection:setHandler("getStatus", handler_getStatus)

connection:connect()
connection:runLoop()