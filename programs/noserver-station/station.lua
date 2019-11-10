require("libevent")
local event=require('event')
local computer=require('computer')
local component=require('component')
local sides=require('sides')

---------- Config ----------
local addr_redin = ""
local addr_redout = ""
local addr_next_station = ""
local limit_train_interval = 10  -- Trains must be separate with this time, should be greater than 2.
----------------------------

local note = component.iron_noteblock
local sign = component.sign
local redin = component.proxy(addr_redin)
local redout = component.proxy(addr_redout)

if not redin or not redout or not sign or not note then
    print("device not ready.")
    return
end

local track_side_map = {
    sides.north,
    sides.east,
    sides.south,
    sides.west
}
local side_track_map = {
    [sides.north] = 1,
    [sides.east] = 2,
    [sides.south] = 3,
    [sides.west] = 4
}

local function setRed(track_id)
    redout.setOutput(track_side_map[track_id], 0)
end

local function setGreen(track_id)
    redout.setOutput(track_side_map[track_id], 15)
end

local function printf(fmt, ...)
    print(string.format(fmt, ...))
end

local workers = {}
local bus = CreateEventBus()
bus:listen("redstone_changed")
bus:listen("_eve_timer")
bus:listen("interrupted")

local function StartTask(fn)
    local c = coroutine.create(fn)
    local ok, ticket = coroutine.resume(c)
    if coroutine.status(c) ~= "dead" then
        workers[ticket] = c
    end
end

local _ticket_holder = 0

local function GenerateTicket()
    _ticket_holder = _ticket_holder + 1
    return string.format("tk_%d", _ticket_holder)
end

local function listenerSleep(second)
    local ticket = GenerateTicket()
    event.timer(second, function()
        event.push("_eve_timer", ticket)
    end, 1)
    -- print("<-- listenerSleep yield.", ticket)
    coroutine.yield(ticket)
    -- print("--> listenerSleep resume.", ticket)
end

local function stationAlarm(second)
    for i=1, second*2 do
        component.iron_noteblock.playNote(6, 6)
        listenerSleep(0.5)
    end
end

-- Try to acquire token that allow train leave station
local global_token_locked = false

local function acquireToken()
    if not global_token_locked then
        global_token_locked = true
        return
    end
    while global_token_locked do
        listenerSleep(1)
    end
    global_token_locked = true
end

local function releaseToken()
    global_token_locked = false
end

local sign_states = {}

local function stationSignUpdate()
    local t = {}
    for i, s in pairs(sign_states) do
        table.insert(t, string.format("[%s]: %s", i, s))
    end
    sign.setValue(sides.up, table.concat(t, '\n'))
end

local function stationAddSign(track_id, status)
    sign_states[track_id] = status
    stationSignUpdate()
end

local function stationClearSign(track_id)
    sign_states[track_id] = nil
    stationSignUpdate()
end

print("Press Ctrl+C to stop.")
while true do
    local e = bus:next(-1, 0.05)
    -- print(e.event)
    if e.event == "interrupted" then
        break
    elseif e.event == "redstone_changed" then
        if e.address == addr_redin and e.newValue == 15 then
            local track_id = side_track_map[e.side]
            if track_id then
                StartTask(function()
                    printf("got train at track %s", track_id)
                    stationAddSign(track_id, "Waiting")
                    listenerSleep(15)
                    acquireToken()
                    printf("track %s acquired token.", track_id)
                    stationAddSign(track_id, "About to leave")
                    printf("start alarm for track %s", track_id)
                    stationAlarm(8)
                    stationAddSign(track_id, "Leaving...")
                    printf("track %s set to green.", track_id)
                    setGreen(track_id)
                    listenerSleep(2.5)
                    printf("track %s set to red.", track_id)
                    setRed(track_id)
                    stationClearSign(track_id)
                    listenerSleep(limit_train_interval - 2)
                    releaseToken()
                    printf("token released at track %s", track_id)
                end)
            end
        end
    elseif e.event == "_eve_timer" then
        local ticket = e.data[1]
        if type(ticket) == "table" then
            for k, v in pairs(ticket) do
                print(k,v)
            end
        end
        -- print("<debug> got ticket", ticket)
        if workers[ticket] then
            local c = workers[ticket]
            workers[ticket] = nil
            -- print("<debug> resuming thread", c)
            local ok, new_ticket = coroutine.resume(c)
            if coroutine.status(c) ~= "dead" then
                workers[new_ticket] = c
            end
        else
            -- print("<debug> ticket not found.", ticket)
        end
    end
end

bus:close()
