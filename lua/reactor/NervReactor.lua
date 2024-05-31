local NervReactor = {}

function NervReactor:new(--[[optional]] opts)
    local o = {}
    local _opts = opts or {}

    -- in mB
    self.activateFuelThreshold = _opts.activateFuelThreshold or 10000
    -- in mB/t
    self.targetBurnRate = _opts.targetBurnRate or 100
    -- in K
    self.maxTemperature = _opts.maxTemperature or 1000

    -- Minimum possible coolant percentage.
    -- The reactor performs adaptive burn rate adjustment, which will
    -- decrease burn rate if coolant is drained too quickly. This percentage
    -- controls when the reactor will SCRAM entirely.
    self.minimumCoolantPercentage = _opts.minimumCoolantPercentage or 0.5

    self.tickRate = _opts.tickRate or 20

    self._reactor = peripheral.find("fissionReactorLogicAdapter")
    if not self._reactor then
        printError("No Fission Reactor Logic Adapter found.")
    end

    -- Actual state
    self._active = false

    setmetatable(o, self)
    self.__index = self
    return o
end

function NervReactor:assertAwake()
	if self._reactor == nil then
		error({ error = true, message = "Reactor not found" })
	end
	if not self._reactor.isFormed() then
		error({ error = true, message = "Reactor is not formed. Ongoing maintenance or catastrophic event?" })
	end
end

function NervReactor:ensureAwake()
    repeat
        self._reactor = peripheral.find("fissionReactorLogicAdapter")
        if not self._reactor then
            printError("Adapter still missing.")
        end
        sleep(0)
    until self._reactor
end

function NervReactor:activate()
    self:assertAwake()
    if self._reactor.getStatus() then
        return
    end
    print("Activating reactor.")
    self._reactor.setBurnRate(1)
    self._reactor.activate()
    self._active = true
end

function NervReactor:deactivate()
    self:assertAwake()
    if not self._reactor.getStatus() then
        return
    end
    print("Deactivating reactor.")
    self._reactor.scram()
    self._active = false
end

function NervReactor:scram()
    repeat
        self:ensureAwake()
    until self._reactor
    print("SCRAM!")
    local success, err = pcall(self._reactor.scram)
    if not success then
        printError("SCRAM failed. Manual intervention required.")
        printError("May God have mercy on your soul.")
        if type(err) ~= "string" then
            printError(textutils.serialize(err))
        else
            printError(err)
        end
    end
    self._active = false
end

function NervReactor:getStatus()
    self:assertAwake()
    local valueFunctions = {
        -- reactor meta
        maxBurnRate = self._reactor.getMaxBurnRate,
        setBurnRate = self._reactor.getBurnRate,
        wasteCapacity = self._reactor.getWasteCapacity,
        fuelCapacity = self._reactor.getFuelCapacity,
        heatCapacity = self._reactor.getHeatCapacity,
        coolantCapacity = self._reactor.getCoolantCapacity,
        heatedCoolantCapacity = self._reactor.getHeatedCoolantCapacity,
        boilEfficiency = self._reactor.getBoilEfficiency,

        -- resources (in mB)
        fuel = self._reactor.getFuel,
        waste = self._reactor.getWaste,
        wasteFilledPercentage = self._reactor.getWasteFilledPercentage,
        coolant = self._reactor.getCoolant,
        heatedCoolant = self._reactor.getHeatedCoolant,

        -- operation
        active = self._reactor.getStatus,
        temperature = self._reactor.temperature,
        heatingRate = self._reactor.getHeatingRate,
        burnRate = self._reactor.getActualBurnRate,
        damage = self._reactor.getDamagePercent,
        environmentalLoss = self._reactor.getEnvironmentalLoss
    }

    local status = {}

	-- Check if the IP is responding properly
	for k, v in pairs(valueFunctions) do
		if v == nil then
			self:ensureAwake()
			break
		end
	end
	
	-- Run detection
	for k, v in pairs(valueFunctions) do
        status[k] = v()
	end

    return status
end

function NervReactor:checkSafety()
    self:assertAwake()

    -- Different status set is used here to ensure that we
    -- don't get too much data when we don't need it, and so
    -- that we can operate with minimal outside info.
    local safetyVariableFunctions = {
        active = self._reactor.getStatus,
        temperature = self._reactor.getTemperature,

        coolantCapacity = self._reactor.getCoolantCapacity,
        coolant = self._reactor.getCoolant,
        heatedCoolantCapacity = self._reactor.getHeatedCoolantCapacity,
        heatedCoolant = self._reactor.getHeatedCoolant,

        burnRate = self._reactor.getBurnRate
    }
    local safetyVariables = {}

	-- Check if the IP is responding properly
	for k, v in pairs(safetyVariableFunctions) do
		if v == nil then
			self:ensureAwake()
			break
		end
	end
	
	-- Run detection
	for k, v in pairs(safetyVariableFunctions) do
        safetyVariables[k] = v()
	end

    safetyVariables.coolantAmount = safetyVariables.coolant.amount
    safetyVariables.heatedCoolantAmount = safetyVariables.heatedCoolant.amount
    
    if self._active and not safetyVariables.active then
        -- The reactor is not active but it is active internally.
        -- It must have been shut down manually.
        -- Set the internal activity flag to false and halt.
        print("Manually deactivated. Stopping...")
        self._active = false
    elseif not self._active and safetyVariables.active then
        -- The reactor is active but it is not active internally.
        -- The reactor should not be allowed to start manually.
        -- SCRAM immediately.
        print("Manually activated. Stopping...")
        self:deactivate()
    end

    if safetyVariables.temperature > 1000 then
        printError("Temperature over 1000K! SCRAM!")
        self:scram()
        os.queueEvent("reactor_needs_scram")
    end
    -- Out of coolant! SCRAM NOW!
    if safetyVariables.coolantAmount < 10000 then
        printError("Coolant gone! SCRAM!")
        self:scram()
        os.queueEvent("reactor_needs_scram")
    end
    -- Full of heated coolant! SCRAM NOW!
    if safetyVariables.heatedCoolantAmount > safetyVariables.heatedCoolantCapacity - 10000 then
        printError("Heated coolant at maximum! SCRAM!")
        self:scram()
        os.queueEvent("reactor_needs_scram")
    end

    -- Ensure that we're not running below the minimum coolant percentage
    if (safetyVariables.coolantAmount / safetyVariables.coolantCapacity) < self.minimumCoolantPercentage then
        -- SCRAM if the coolant is running low.
        printError("Coolant running low. SCRAM at soonest.")
        os.queueEvent("reactor_needs_scram")
    end

    if self._lastSafetyVariables == nil then
        self._lastSafetyVariables = safetyVariables
    else
        -- Check coolant delta, and slow down if we're going to burn out
        -- within 60 seconds, SCRAM if we're going to burn out within 10.
        local coolantDeltaTick = safetyVariables.coolantAmount - self._lastSafetyVariables.coolantAmount
        if coolantDeltaTick < 0 then
            -- This burn rate is dangerous, we need to avoid going higher
            -- than it.
            self.criticalBurnRate = safetyVariables.burnRate
            print("Current burn rate is DANGEROUS: " .. safetyVariables.burnRate .. " mB/t")

            local ticksToEmpty = safetyVariables.coolantAmount / math.abs(coolantDeltaTick)
            local secondsToEmpty = ticksToEmpty / self.tickRate

            if ticksToEmpty < 10 then
                -- No time to spare, SCRAM NOW!
                printError(string.format("%.2fs/%dft to empty. SCRAM!", secondsToEmpty, ticksToEmpty))
                self:scram()
                os.queueEvent("reactor_needs_scram")
            elseif secondsToEmpty < 10 then
                printError(string.format("%.2fs/%dft to empty. SCRAM when able.", secondsToEmpty, ticksToEmpty))
                os.queueEvent("reactor_needs_scram")
            elseif secondsToEmpty < 60 then
                print(string.format("%.2fs/%dft to empty. Slowing down.", secondsToEmpty, ticksToEmpty))
                local newBurnRate = safetyVariables.burnRate * 0.5
                self._reactor.setBurnRate(newBurnRate)
                print("Now at burn rate of " .. newBurnRate .. " mB/t")
            end
        end

        -- Check heated coolant delta, SCRAM immediately if it keeps rising
        -- for two ticks. This usually indicates turbine failure or capping.
        -- The turbine should call for a SCRAM itself, but this check exists
        -- in case it ends up lagging behind.
        local heatedCoolantDeltaTick = safetyVariables.heatedCoolantAmount - self._lastSafetyVariables.heatedCoolantAmount
        if heatedCoolantDeltaTick > 0 then
            if self._lastSafetyVariables.criticalHeatedCoolantDelta > 0 then
                printError("Heated coolant is rising. SCRAM at soonest.")
                os.queueEvent("reactor_needs_scram")
            end
        end
    end
end

function NervReactor:onScram()
    os.pullEvent("reactor_needs_scram")
    self:scram()
end

function NervReactor:onPeripheralChange()
    repeat
        os.pullEvent("peripheral_change")
    until self._reactor == nil
    print("Lost the Fission Reactor Logic Adapter. Reconnecting...")
    self:ensureAwake()
end

function NervReactor:onRunLoop()
    while true do
        local success, _err = pcall(NervReactor.checkSafety, self)
        if not success then
            printError("Safety check had an error. SCRAM for safety!")
            if type(_err) ~= "string" then
                printError(textutils.serialize(_err))
            else
                printError(_err)
            end
            self:scram()
            os.queueEvent("reactor_needs_scram")
        elseif self._active then
            -- If we're not at the target burn rate, increase by 1 mB/t for every
            -- second.
            -- os.epoch in milliseconds.
            if self._lastBurnRateIncrease == nil then
                self._lastBurnRateIncrease = os.epoch("utc")
            elseif os.epoch("utc") > self._lastBurnRateIncrease + 1000 then
                local actualTargetBurnRate = self.targetBurnRate
                if self.criticalBurnRate ~= nil and actualTargetBurnRate > self.criticalBurnRate then
                    actualTargetBurnRate = self.criticalBurnRate
                end

                if self._reactor.getBurnRate() < actualTargetBurnRate then
                    local newBurnRate = math.max(self._reactor.getBurnRate() + 1, 0.01)
                    print("Increasing burn rate to " .. newBurnRate .. " mB/t")
                    self._reactor.setBurnRate(newBurnRate)
                end

                -- 5% chance of increasing the critical burn rate by 1 mB/t,
                -- if it was set previously. This allows for slow recovery
                -- after hitting a critical burn rate.
                if self.actualTargetBurnRate ~= nil then
                    if math.random(0, 20) == 0 then
                        self.criticalBurnRate = self.criticalBurnRate + 1
                        print("Critical burn rate recovery: now " .. self.criticalBurnRate .. " mB/t")
                    end
                end

                self._lastBurnRateIncrease = os.epoch("utc")
            end
        end
        sleep(0)
    end
end

function NervReactor:getEventLoop()
    local function bind(func)
        return function() return func(self) end
    end

    local function onKeyDown()
        local key
        repeat
            _, key = os.pullEvent("key")
        until key == keys.enter
        if self._active then
            self:deactivate()
        else
            self:activate()
        end
    end

    return {
        onKeyDown,
        bind(NervReactor.onScram),
        bind(NervReactor.onPeripheralChange),
        bind(NervReactor.onRunLoop)
    }
end

return NervReactor