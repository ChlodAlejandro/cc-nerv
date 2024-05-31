local NervConnection = require("../shared/NervConnection")
local NervReactor = require("./NervReactor")
-- local NervTurbine = require("../shared/NervTurbine")
-- local NervReactorMonitor = require("../shared/NervReactorMonitor")

print("======================================");
print("        _   ____________ _    __      ");
print("       / | / / ____/ __ \\ |  / /      ");
print("      /  |/ / __/ / /_/ / | / /       ");
print("     / /|  / /___/ _, _/| |/ /        ");
print("    /_/ |_/_____/_/ |_| |___/         ");
print("                                      ");
print("======================================");
print("Starting up!")

local reactor = NervReactor:new()
-- local turbine = NervTurbine:new()
-- local monitor = NervReactorMonitor:new()
local connection = NervConnection:new{}

local startTimer

print("Declaring handlers...")

local function handler_getStatus(_conn, data)
	return reactor:getStatus()
end

connection:setHandler("getStatus", handler_getStatus)

print("Declaring coroutines...")

local function onPeripheral()
    -- Ensure all peripherals are still connected
    os.pullEvent("peripheral")
    os.queueEvent("peripheral_change")
end

local function onPeripheralDetach()
    -- Ensure all peripherals are still connected
    os.pullEvent("peripheral_detach")
    os.queueEvent("peripheral_change")
end

local function onTimer()
    local event, timer = os.pullEvent("timer")
    if timer == startTimer then
        print("Starting reactor...")
        reactor:activate()
    end
end

connection:connect()

print("Starting reactor in 10 seconds...")
startTimer = os.startTimer(10)

connection:runLoop(
    onPeripheral,
    onPeripheralDetach,
    onTimer,
    unpack(reactor:getEventLoop())
)