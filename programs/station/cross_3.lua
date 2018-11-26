--[[
    Cross 3	Standard Schedule Program
]]
require("libevent")
require("util")
require("checkarg")
require("queue")
local sides = require("sides")

-- Config your update functions here (Do not change variable name)
local redin1 = proxy("redstone", "02")
local redin2 = proxy("redstone", "a9")
local redin3 = proxy("redstone", "ab")
local redout1 = proxy("redstone", "ca")
local redout2 = proxy("redstone", "f3")

-- Redirect Table
local redirect_tb = {
    -- Inputs
    ["ab_st"] = {redin1, sides.north},
    ["ab_sr"] = {redin1, sides.east},
    ["ab_lout"] = {redin1, sides.south},
    ["ab_left"] = {redin1, sides.west},

    ["ba_st"] = {redin2, sides.north},
    ["ba_sr"] = {redin2, sides.east},
    ["ba_lout"] = {redin2, sides.south},
    ["ba_left"] = {redin2, sides.west},

    ["c_st"] = {redin3, sides.north},
    ["c_sr"] = {redin3, sides.east},
    ["c_lout"] = {redin3, sides.south},
    ["c_left"] = {redin3, sides.west},

    -- Outputs
    ["ab_ks"] = {redout1, sides.north},
    ["ab_m"] = {redout1, sides.east},
    ["ba_ks"] = {redout1, sides.south},
    ["ba_m"] = {redout1, sides.west},
    ["c_ks"] = {redout2, sides.north},
    ["c_m"] = {redout2, sides.east},

    ["last_unused"] = {"unused", sides.north}
}

local function getNameFromRaw(Device, Side)
    for k, t in pairs(redirect_tb) do
        if (t[1].address == Device and t[2] == Side) then
            return k
        end
    end

    return nil
end

local function getRawFromName(Name)
    return redirect_tb[Name][1], redirect_tb[Name][2]
end

local function enabledevice(Name)
    local d, s = getRawFromName(Name)
    if (d ~= nil and s ~= nil) then
        d.setOutput(s, 15)
    end
end

local function disabledevice(Name)
    local d, s = getRawFromName(Name)
    if (d ~= nil and s ~= nil) then
        d.setOutput(s, 0)
    end
end

local function readdevice(Name)
    local d, s = getRawFromName(Name)
    if (d ~= nil and s ~= nil) then
        return d.getInput(s)
    else
        -- Critical error
        error("failed to read device input")
    end
end

local function trigger(Name)
    enabledevice(Name)
    os.sleep(0.25)
    disabledevice(Name)
end

local evl = Queue.new()

local function redstone_delegator(Name, callback_func)
	print("Add Redstone Delegator ",Name,callback_func)
    evl:push(
        AddEventListener(
            "redstone_changed",
            function(ev, dev, sd, from, to)
                if (getNameFromRaw(dev, sd) == Name) then
                    print("Calling callback:",callback_func,from,to)
                    callback_func(from, to)
                end
            end
        )
    )
end

local bus = Queue.new()

local function redstone_event(DeviceName, OnEvent, OffEvent)
	checkstring(OnEvent)
	checkstring(OffEvent)
    redstone_delegator(
            DeviceName,
            function(from, to)
                if (from < to) then
                    bus:push(OnEvent)
                else
                    bus:push(OffEvent)
                end
            end
        )
end

local function doInit()
    evl:push(
        AddEventListener(
            "interrupted",
            function()
                bus:push("stop")
            end
        )
    )

    redstone_event("ab_st", "a_new_train", "a_train_left")
    redstone_event("ba_st", "b_new_train", "b_train_left")
    redstone_event("c_st", "c_new_train", "c_train_left")
    redstone_event("ab_left", "b_detect_start", "b_detect_end")
    redstone_event("ba_left", "a_detect_start", "a_detect_end")
    redstone_event("c_left", "c_detect_start", "c_detect_end")
end

local function doCleanUp()
    while (evl:top() ~= nil) do
        RemoveEventListener(evl:pop())
    end
end

-- Status
-- Out busy flag
local a_busy, b_busy, c_busy = false, false, false
local crosslocked = false

local function doCheck()
    for k, vt in pairs(redirect_tb) do
        if (vt[1] == nil) then
            error("Check Failed. Please review your redstone configure")
        end
    end

    print("Check Pass.")
end

local function doClearOutput()
    local smt = {"ab_ks", "ab_m", "ba_ks", "ba_m", "c_ks", "c_m"}

    for k, v in pairs(smt) do
        disabledevice(v)
    end
end

local function CCSMain()
    doCheck()
    doClearOutput()
    doInit()

    print("CCS Started. Press Ctrl+C to stop.")
    local running = true
    while (running) do
        os.sleep(0.25)
        local ev = "no_event"
        if (bus:top() ~= nil) then
            ev = bus:pop()
        end

        if (ev ~= "no_event") then
            print(ev)
        end

        if (ev == "no_event") then
            -- No event, no action.
        elseif (ev == "stop") then
            running = false
        elseif (ev == "delay") then
            os.sleep(0.25)
        elseif (ev == "a_new_train") then -- New Train From A
            local done = false
            if (readdevice("ab_sr") > 0) then -- Turn to C
                if ((not c_busy) and (not crosslocked) and readdevice("c_lout") > 0) then
                    c_busy = true
                    crosslocked = true
                    enabledevice("ab_m")
                    trigger("ab_ks")
                    done = true
                end
            else -- Go directly to B
                if ((not b_busy) and (not crosslocked) and readdevice("ab_lout") > 0) then
                    b_busy = true
                    crosslocked = true
                    disabledevice("ab_m")
                    trigger("ab_ks")
                    done = true
                end
            end

            if (not done) then
                bus:push(ev)
            end
        elseif (ev == "b_new_train") then -- New Train From B
            local done = false
            if (readdevice("ba_sr") > 0) then -- Turn to C
                if ((not c_busy) and readdevice("c_lout") > 0) then
                    c_busy = true
                    enabledevice("ba_m")
                    trigger("ba_ks")
                    done = true
                end
            else -- Go directly to A
                if ((not a_busy) and (not crosslocked) and readdevice("ba_lout") > 0) then
                    a_busy = true
                    crosslocked = true
                    disabledevice("ba_m")
                    trigger("ba_ks")
                    done = true
                end
            end

            if (not done) then
                bus:push(ev)
            end
        elseif (ev == "c_new_train") then -- New Train From C
            local done = false
            if (readdevice("c_sr") > 0) then -- Turn to A
                if ((not a_busy) and readdevice("ba_lout") > 0) then
                    a_busy = true
                    enabledevice("c_m")
                    trigger("c_ks")
                    done = true
                end
            else -- Go directly to B
                if ((not b_busy) and (not crosslocked) and readdevice("ab_lout") > 0) then
                    b_busy = true
                    crosslocked = true
                    disabledevice("c_m")
                    disabledevice("ab_m") -- Must Asure this motor is disabled (So we can move to B)
                    trigger("c_ks")
                    done = true
                end
            end

            if (not done) then
                bus:push(ev)
            end
        elseif (ev == "a_detect_end") then
            a_busy = false
            crosslocked = false
        elseif (ev == "b_detect_end") then
            b_busy = false
            crosslocked = false
        elseif (ev == "c_detect_end") then
            c_busy = false
            crosslocked = false
        else
            print("Ignoring:", ev)
        end
	end
	
	doCleanUp()
	doClearOutput();
end

print("Program Start")
CCSMain()
print("Program Stop")