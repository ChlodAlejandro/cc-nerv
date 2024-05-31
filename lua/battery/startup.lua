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

local ip
local connection = NervConnection:new{}

local function detectIP()
	repeat
		ip = peripheral.find("inductionPort")

		if not ip then
			printError("No Induction Port found. Trying again in 30 seconds.")
			sleep(30)
		end
	until ip
end
detectIP()

print("Declaring tracking variables...")
local samplerTimer
local sampleLimit = 2400
local sampleInterval = 10
local lastInputSamples = {}
local lastOutputSamples = {}

print("Declaring functions...")

local function assertIPAwake()
	if ip == nil then
		error("Induction Matrix not found.")
	end

	if not ip.isFormed() then
		error("Induction Matrix is not formed. Ongoing maintenance?")
	end
end

local function getAverageInput()
	local sum = 0
	for i = 1, #lastInputSamples do
		sum = sum + lastInputSamples[i]
	end
	local result = sum / #lastInputSamples
	if result == nil or --[[ nan check ]] result ~= result then
		return nil
	else
		return result
	end
end

local function getAverageOutput()
	local sum = 0
	for i = 1, #lastOutputSamples do
		sum = sum + lastOutputSamples[i]
	end
	local result = sum / #lastInputSamples
	if result == nil or --[[ nan check ]] result ~= result then
		return nil
	else
		return result
	end
end

local function getStatus(units)
	assertIPAwake()

	if string.lower(units) == "j" then
		units = "J"
	else
		units = "FE"
	end
	
	local valueFunctions = {
		cells = ip.getInstalledCells,
		providers = ip.getInstalledProviders,
		energy = ip.getEnergy,
		energyCapacity = ip.getMaxEnergy,
		energyPercentage = ip.getEnergyFilledPercentage,
		lastInput = ip.getLastInput,
		lastOutput = ip.getLastOutput,
		avgInput = getAverageInput,
		avgOutput = getAverageOutput,
		transferCap = ip.getTransferCap
	}
	
	local status = { units = units }
	local numValues = {}
	
	-- Check if the IP is responding properly
	for k, v in pairs(valueFunctions) do
		if v == nil then
			detectIP()
			break
		end
	end
	
	-- Run detection
	for k, v in pairs(valueFunctions) do
		if k == "cells" or k == "providers" or k == "energyPercentage" then
			status[k] = v()
		else
			-- Units are always in J
			numValues[k] = v()
		end
	end
	
	-- Apply unit conversions
	for k, v in pairs(numValues) do
		if units == "FE" then
			status[k] = v / 2.5
		else
			status[k] = v
		end
	end

	return status
end

local function recordSample()
	local isAwake, _err = pcall(assertIPAwake)
	if not isAwake then
		return _err
	end

	if #lastInputSamples > sampleLimit then
		table.remove(lastInputSamples, 1)
	end
	if #lastOutputSamples > sampleLimit then
		table.remove(lastOutputSamples, 1)
	end
	local input = ip.getLastInput()
	local output = ip.getLastOutput()

	table.insert(lastInputSamples, input)
	table.insert(lastOutputSamples, output)

	samplerTimer = os.startTimer(sampleInterval)
end

print("Declaring handlers...")

local function handler_getStatus(_conn, data)
	local isAwake, _err = pcall(getStatus, data.units or "FE")
	if isAwake then
		return _err
	else
		return { error = true, message = _err }
	end
end

local function handler_flushSamples(_conn, _data)
	lastInputSamples = {}
	lastOutputSamples = {}
	return { ok = true }
end

connection:setHandler("getStatus", handler_getStatus)
connection:setHandler("flushSamples", handler_flushSamples)

print("Declaring coroutines...")

local function onTimerRecordSample()
	local _, id
	repeat
		_, id = os.pullEvent("timer")
	until id == samplerTimer
	recordSample()
end

connection:connect()
samplerTimer = os.startTimer(sampleInterval)
connection:runLoop(onTimerRecordSample)
