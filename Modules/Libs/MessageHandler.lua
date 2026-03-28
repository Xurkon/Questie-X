---@class MessageHandlerFactory
local MessageHandlerFactory = setmetatable(QuestieLoader:CreateModule("MessageHandlerFactory"),
    { __call = function(self) return self.New() end })

---@alias Event string
---@alias Callback fun(...:any):any

--- COMPATIBILITY ---
local C_Timer = QuestieCompat.C_Timer

--- Localize functions
local yield = coroutine.yield
local insert, remove = table.insert, table.remove
local wipe = wipe

--- Creates a new MessageHandler
---@return MessageHandler
function MessageHandlerFactory.New()
    ---@class MessageHandler
    local handler = {}

    --- Contains all the events that are fired repeatably
    ---@type table<Event,Callback[]>
    handler.repeatEvents = {}

    --- Contains all the events that are fired once
    ---@type table<Event,Callback[]>
    handler.onceEvents = {}

    -- Used when asyncronously calling events
    ---@type table<Event, boolean>
    handler.executing = {}

    --- The local function for both Async and Sync callbacks
    ---@param eventName Event
    ---@param asyncCount number? @How many events to fire per yield
    ---@param ... any @Input arguments for the callback
    ---@return table? @Returns a table of all the return values from the callbacks
    local function fire(eventName, asyncCount, ...)
        if handler.executing[eventName] then
            error("Event '" .. eventName .. "' is already being executed!", 2)
        end

        handler.executing[eventName] = true

        --* Fire once tables
        if handler.onceEvents[eventName] then
            local eventList = handler.onceEvents[eventName]
            for callbackIndex = 1, #eventList do
                -- Function call
                eventList[callbackIndex](...)
            end
            wipe(eventList)
        end

        --* Fire repeat tables
        local returnValues = nil
        if handler.repeatEvents[eventName] then
            local eventList = handler.repeatEvents[eventName]
            for callbackIndex = 1, #eventList do
                -- Function call
                local retValue = eventList[callbackIndex](...)

                -- If we have a return value we save it to the return table
                if retValue then
                    if not returnValues then returnValues = {} end
                    returnValues[#returnValues + 1] = retValue
                end

                --If we are a async function we yield after each asyncCount
                if asyncCount and callbackIndex % asyncCount == 0 then
                    yield()
                end
            end
        end
        handler.executing[eventName] = nil

        return returnValues
    end

    --- Fire a callback event
    ---@param eventName Event
    ---@param ... any @Input arguments for the callback
    ---@return table? @A table containing all the return values
    function handler:Fire(eventName, ...)
        return fire(eventName, nil, ...)
    end

    --- Fire a async callback event which invokes coroutine yield
    ---@param eventName Event
    ---@param asyncCount number? @How many events to fire per yield
    ---@param ... any @Input arguments for the callback
    ---@return table? @A table containing all the return values
    function handler:FireAsync(eventName, asyncCount, ...)
        local returnValues = fire(eventName, asyncCount, ...)
        --? We call yield here returning the value to the calling resume, makes it take one more resume to finish
        yield(returnValues)
        return returnValues
    end

    ---Register a callback
    ---@param eventName Event
    ---@param callback Callback
    function handler:RegisterRepeating(eventName, callback)
        if not callback or type(callback) ~= "function" then
            error("Usage: Register(eventName, callback): 'callback' - function expected.", 2)
        elseif not eventName or type(eventName) ~= "string" then
            error("Usage: Register(eventName, callback): 'eventName' - a string expected.", 2)
        end
        if not self.repeatEvents[eventName] then
            self.repeatEvents[eventName] = {}
        end
        insert(self.repeatEvents[eventName], callback)
    end

    --- Register a callback that will only be called once
    ---@param eventName Event
    ---@param callback Callback
    function handler:RegisterOnce(eventName, callback)
        if not callback or type(callback) ~= "function" then
            error("Usage: RegisterOnce(eventName, callback): 'callback' - function expected.", 2)
        elseif not eventName or type(eventName) ~= "string" then
            error("Usage: RegisterOnce(eventName, callback): 'eventName' - a string expected.", 2)
        end
        if not self.onceEvents[eventName] then
            self.onceEvents[eventName] = {}
        end
        insert(self.onceEvents[eventName], callback)
    end

    ---Unregister a callback by function
    ---@param eventName Event
    ---@param callback Callback
    function handler:UnregisterRepeating(eventName, callback)
        if not callback or type(callback) ~= "function" then
            error("Usage: Unregister(eventName, callback): 'callback' - function expected.", 2)
        elseif not eventName or type(eventName) ~= "string" then
            error("Usage: Unregister(eventName, callback): 'eventName' - a string expected.", 2)
        end
        local eventList = self.repeatEvents[eventName]
        if eventList then
            for callbackIndex = 1, #eventList do
                if eventList[callbackIndex] == callback then
                    remove(self.repeatEvents[eventName], callbackIndex)
                    return
                end
            end
        end
    end

    ---Unregisters all events for a given event name in repeat and once-lists
    ---@param eventName Event
    function handler:UnregisterAll(eventName)
        if not eventName or type(eventName) ~= "string" then
            error("Usage: UnregisterAll(eventName): 'eventName' - a string expected.", 2)
        end
        if self.repeatEvents[eventName] then
            wipe(self.repeatEvents[eventName])
        end
        if self.onceEvents[eventName] then
            wipe(self.onceEvents[eventName])
        end
    end

    return handler
end
