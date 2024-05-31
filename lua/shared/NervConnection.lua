NervConnection = {}

function NervConnection:new(--[[optional]] opts)
    local o = {}
    local _opts = opts or {}

    -- User parameters
    self.handlers = _opts.handlers or {}
    self.listenAddress = _opts.listenAddress or "wss://nerv.chlod.net/ws"

    -- Internal parameters
    -- Use a random listen ID to get unique URLs even if multiple computers are running the same code.
    self._listenId = tostring(math.random()):sub(3);
    self._listenAddress = self.listenAddress .. "?listenId=" .. self._listenId
    self._connectionRetryCount = 0
    self._ws = nil
    self._messageQueue = {}

    self._hadFatalDisconnect = false
    self._disconnecting = false

    setmetatable(o, self)
    self.__index = self
    return o
end

function NervConnection:setHandler(type, handler)
    self.handlers[type] = handler
end

function NervConnection:connect()
    if self._ws then
        print("Already connected.")
        return
    end

    print("Connecting to " .. self.listenAddress)
    print(" :: Connection ID: " .. self._listenId)
    self._ws = http.websocket(self._listenAddress)

    if not self._ws then
        printError("Failed to connect.")
        self._connectionRetryCount = self._connectionRetryCount + 1
        self:reconnectWait()
        return self:connect()
    end

    print("Connected. Ctrl + D to disconnect.")
    self._hadFatalDisconnect = false
    self:handshake()
end

function NervConnection:disconnect()
    print("Disconnecting...")
    self._disconnecting = true
    if self._ws then
        self._ws.close()
    end
end

function NervConnection:reconnectWait()
    if self._disconnecting then
        return
    end
	local waitTime = (math.min(9, math.floor(self._connectionRetryCount / 10)) + 1) * 30
	print("Reconnecting in " .. waitTime .. " seconds.")
	sleep(waitTime)
end

function NervConnection:onClosed()
    local url
    repeat
        _, url = os.pullEvent("websocket_closed")
    until url == self._listenAddress

    if self._disconnecting then
        return
    end

    if self._hadFatalDisconnect then
        print("Socket closed. Reconnecting in 10 seconds.")
        self._ws = nil
        sleep(10)
        self:connect()
    else
        print("Socket closed. Reconnecting...")
        self._ws = nil
        self:connect()
    end
end

function NervConnection:onMessage()
    local url, message
    repeat
        _, url, message = os.pullEvent("websocket_message")
    until url == self._listenAddress

    local data = textutils.unserializeJSON(message)
    local handler = self:_getHandler(data.type)
    if handler == nil then
        printError("Unknown type: " .. data.type .. "!")
        printError("Skipping...")
    else
        if data.type ~= "ping" then
            print("Processing request: " .. data.type)
        end
        local success, error = pcall(handler, self, data)
        if not success then
            printError("Error processing request: " .. error)
        end
    end
end

-- Run the event loop
-- Allows extra coroutines to be passed into the loop
function NervConnection:runLoop(...)
    local extraCoroutines = { ... };
    if #extraCoroutines > 0 then
        print(#extraCoroutines .. " extra coroutines detected.")
    end

    local function onClosed_bound()
        self:onClosed()
    end
    local function onMessage_bound()
        self:onMessage()
    end
    local function onKeyUp()
        local key
        repeat
            _, key = os.pullEvent("key_up")
        until key == keys.leftCtrl or key == keys.rightCtrl
        if key == keys.leftCtrl then
            self._leftCtrlHeld = false
        elseif key == keys.rightCtrl then
            self._rightCtrlHeld = false
        end
    end
    local function onKeyDown()
        local key
        repeat
            _, key = os.pullEvent("key")
        until key == keys.d or key == keys.leftCtrl or key == keys.rightCtrl
        if key == keys.leftCtrl then
            self._leftCtrlHeld = true
        elseif key == keys.rightCtrl then
            self._rightCtrlHeld = true
        elseif key == keys.d and (self._leftCtrlHeld or self._rightCtrlHeld) then
            self:disconnect()
        end
    end

    print("Ready for messages.");
    while not self._disconnecting do
        parallel.waitForAny(
            onClosed_bound,
            onMessage_bound,
            onKeyDown,
            onKeyUp,
            unpack(extraCoroutines)
        )
    end
end

function NervConnection:send(type, data)
    if self._ws == nil then
        table.insert(self._messageQueue, { type = type, data = data })
        return
    end

    local packet = data or {}
    packet.type = type
    local message = textutils.serializeJSON(
        packet,
        { allow_repetitions = true }
    )

    local success, error = pcall(self._ws.send, message)
    if not success then
        printError("Failed to send message. Connection lost?")
        printError("Error: " .. error)
    end
end

function NervConnection:handshake()
    print("Performing handshake...")
    self:send("handshake", {
        computerId = os.getComputerID(),
        computerLabel = os.getComputerLabel()
    })
end

local function _handler_error(conn, data)
	printError("Received fatal server error: " .. data.message)
    conn._hadFatalDisconnect = true
	conn._ws = nil
end

local function _handler_handshakeOK(conn, data)
	print("Handshake success!")
	conn._connectionRetryCount = 0

    -- Attempt to resend messages that were stuck
    local messageQueue = conn._messageQueue
    conn._messageQueue = {}
    for _, message in ipairs(messageQueue) do
        conn:send(message.type, message.data)
    end
end

local function _handler_closed(conn, data)
    print("Server closed. Reconnecting in 30 seconds.")
    conn._ws = nil
    sleep(30)
    conn:connect()
end

local function _handler_runJob(conn, data)
    print("Received job request: " .. data.jobType)
    local handler = conn:_getHandler(data.jobType)
    if handler == nil then
        printError("Unknown type: " .. data.jobType .. "!")
        printError("Skipping...")
    else
        print("Processing job request: " .. data.jobType)
        local success, results = pcall(handler, conn, data)
        if not success then
            printError("Error processing job: " .. results)
            results = { 
                error = true,
                message = results,
                jobId = data.jobId
            }
        else
            results = results or {}
            results.jobId = data.jobId
        end
        conn:send("finishJob", results)
    end
end

local function _handler_ping(conn, data)
    conn:send("pong")
end

NervConnection._defaultHandlers = {
    error = _handler_error,
    handshakeOK = _handler_handshakeOK,
    closed = _handler_closed,
    runJob = _handler_runJob,
    ping = _handler_ping
}

function NervConnection:_getHandler(type)
    return self.handlers[type] or self._defaultHandlers[type] or nil
end

return NervConnection