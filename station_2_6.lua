--[[
    Station 2/6 Standard Schedule Program
]]
require("libevent")
require("util")
require("checkarg")
require("queue")
local sides = require("sides")

-- Config your update functions here (Do not change variable name)
local redin1 = proxy("redstone", "a0")
local redin2 = proxy("redstone", "4d")
local redin3 = proxy("redstone", "3f")
local redin4 = proxy("redstone", "b7")
local redout1 = proxy("redstone", "bd")
local redout2 = proxy("redstone", "0a")
local redout3 = proxy("redstone", "90")
local redout4 = proxy("redstone", "53")

-- Redirect Table
local redirect_tb = {
    ["ab_st"] = {redin1, sides.north},
    ["ab_sr"] = {redin1, sides.east},
    ["ab_sv"] = {redin1, sides.south},
    ["ab_lout"] = {redin1, sides.west},
    ["ba_st"] = {redin2, sides.north},
    ["ba_sr"] = {redin2, sides.east},
    ["ba_sv"] = {redin2, sides.south},
    ["ba_lout"] = {redin2, sides.west},
    -- ins: Inside station sensor
    ["s1"] = {redin3, sides.north},
    ["s2"] = {redin3, sides.east},
    ["s3"] = {redin3, sides.south},
    ["s4"] = {redin3, sides.west},
    ["s5"] = {redin4, sides.north},
    ["s6"] = {redin4, sides.east},
    ["st_l"] = {redin4, sides.south},
    -- Output
    ["m1"] = {redout1, sides.north},
    ["m2"] = {redout1, sides.east},
    ["m3"] = {redout1, sides.south},
    ["m4"] = {redout1, sides.west},
    ["m5"] = {redout2, sides.north},
    ["m6"] = {redout2, sides.east},
    ["k1"] = {redout2, sides.south},
    ["k2"] = {redout2, sides.west},
    ["k3"] = {redout3, sides.north},
    ["k4"] = {redout3, sides.east},
    ["k5"] = {redout3, sides.south},
    ["k6"] = {redout3, sides.west},
    ["ab_ko"] = {redout4, sides.north},
    ["ba_ko"] = {redout4, sides.east},
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

local function train_delegator(Name, callback_func)
    evl:push(
        AddEventListener(
            "redstone_changed",
            function(ev, dev, sd, from, to)
                if (getNameFromRaw(dev, sd) == Name) then
                    callback_func(from, to)
                end
            end
        )
    )
end

-- Data for 6 ways.
local isfree = {true, true, true, true, true, true}
local timerid = {-1, -1, -1, -1, -1, -1}
local timecnt = {0, 0, 0, 0, 0, 0}
local revflag = {false, false, false, false, false, false}
local ab_timerid_out, ab_time_out = 0, 0
local ba_timerid_out, ba_time_out = 0, 0
local _side_line_free = true
local _side_line_hw = true
local _auto_unlock_side_line_hw = false

local function isSideLineFree()
    return _side_line_free and _side_line_hw
end

local function lockSideLine()
    _side_line_free = false
end

local function unlockSideLine()
    if (not _auto_unlock_side_line_hw) then -- Manual
        _side_line_free = true
    end -- else it will be unlock automatically
end

local function setSideLineAutoUnlock(flag)
    checkbool(flag)
    _auto_unlock_side_line_hw = flag
    if (flag) then
        print("SideLine AutoUnlock is now enabled")
    else
        print("SideLine AutoUnlock is not disabled")
    end
end

local bus = Queue.new()

local function addNormalStationTimer(n) -- Add Normal Timer
    checknumber(n)
    if (timerid[n] ~= -1) then
        print("Error: add another timer to station ", n)
        bus:push("halt")
    end
    timecnt[n] = 1
    timerid[n] =
        AddTimer(
        1,
        function()
            timecnt[n] = timecnt[n] + 1
            if (timecnt[n] == 5) then
                bus:push("s" .. n .. "_timeout")
            end
        end,
        -1
    )
end

local function addSimpleStationTimer(n) -- Add Simple Timer
    checknumber(n)
    if (timerid[n] ~= -1) then
        print("Error: add another timer to station ", n)
        bus:push("halt")
    end
    timecnt[n] = 1
    timerid[n] =
        AddTimer(
        1,
        function()
            timecnt[n] = timecnt[n] + 1
        end,
        -1
    )
end

local function stopTimer(n) -- Stop Timer
    checknumber(n)
    if (timerid[n] == -1) then
        print("Error: stopping a non-exist timer")
        bus:push("halt")
    end
    RemoveTimer(timerid[n])
    timerid[n] = -1
    timecnt[n] = 0
end

local function doInit()
    setSideLineAutoUnlock(true)

    evl:push(
        AddEventListener(
            "interrupted",
            function()
                bus:push("stop")
            end
        )
    )

    train_delegator(
        "ab_st",
        function(from, to)
            if (from < to) then
                bus:push("ab_new_train")
            end
        end
    )

    train_delegator(
        "ba_st",
        function(from, to)
            if (from < to) then
                bus:push("ba_new_train")
            end
        end
    )

    train_delegator(
        "st_l",
        function(from, to)
            if (from < to) then -- Red to Green.
                _side_line_hw = true
                if (_auto_unlock_side_line_hw) then
                    _side_line_free = true
                end
            else -- Green to Red.
                _side_line_hw = false
            end
        end
    )

    local smt = {"s1", "s2", "s3", "s4", "s5", "s6"}
    for k, v in pairs(smt) do
        train_delegator(
            v,
            function(from, to)
                if (from < to) then
                    bus:push(v .. "_ready")
                else
                    bus:push(v .. "_empty")
                end
            end
        )
    end
end

local function doCleanUp()
    while (evl:top() ~= nil) do
        RemoveEventListener(evl:pop())
    end
end

local function doClearOutput()
    local smt = {"m1", "m2", "m3", "m4", "m5", "m6", "k1", "k2", "k3", "k4", "k5", "k6", "ab_ko", "ba_ko"}

    for k, v in pairs(smt) do
        disabledevice(v)
    end
end

local function doCheck()
    for k, vt in pairs(redirect_tb) do
        if (vt[1] == nil) then
            error("Check Failed. Please review your redstone configure")
        end
    end

    print("Check Pass.")
end

local function startABTimer()
    ab_time_out = 1
    ab_timerid_out =
        AddTimer(
        1,
        function()
            ab_time_out = ab_time_out + 1
            if (ab_time_out == 8) then
                bus:push("ab_time_out_needstop")
            end
        end,
        -1
    )
end

local function startBATimer()
    ba_time_out = 1
    ba_timerid_out =
        AddTimer(
        1,
        function()
            ba_time_out = ba_time_out + 1
            if (ba_time_out == 8) then
                bus:push("ba_time_out_needstop")
            end
        end,
        -1
    )
end

local function proc1236(n, ev)
    checknumber(n)
    local done = false
    if (isSideLineFree()) then -- Side line must be free(or we can't move at all)
        if (timecnt[n] >= timecnt[1] and timecnt[n] >= timecnt[2] and timecnt[n] >= timecnt[3] and timecnt[n] >= timecnt[6]) then
            if (revflag[1]) then -- Way n need reverse
                if (isfree[4]) then -- Way n --> Way 4
                    isfree[4] = false
                    revflag[4] = false
                    disabledevice("m3")
                    disabledevice("m4")
                    disabledevice("k4")
                    done = true
                elseif (isfree[5]) then --- Way n --> Way5
                    isfree[5] = false
                    revflag[5] = false
                    disabledevice("m3")
                    enabledevice("m4")
                    disabledevice("k5")
                    done = true
                end
            else -- Way n does not need reverse
                if (ab_time_out == 0 and readdevice("ab_lout") > 0) then -- Can move to next station (B)
                    startABTimer()
                    enabledevice("m3")
                    done = true
                end
            end
        end
    end

    if (done) then -- Clear way n
        stopTimer(n)
        isfree[n] = true
        lockSideLine()
        trigger("k" .. n)
        unlockSideLine()
    else
        bus:push(ev)
    end
end

local function TCSMain()
    doCheck()
    doClearOutput()
    doInit()

    print("TCS Started. Press Ctrl+C to stop.")

    -- Main Processing Loop
    local running = true
    while (running) do
        os.sleep(0.25) -- Shorter sleep, faster program.

        local ev = "no_event"
        if (bus:top() ~= nil) then
            ev = bus:pop() -- Notice: Event is already poped.
        end

        -- For Debug: Print Event Name
        if (ev ~= "no_event") then
            print(ev)
        end

        if (ev == "no_event") then
            -- No event, no action.
        elseif (ev == "stop") then
            running = false
        elseif (ev == "halt") then
            print("Exception Occured! Something goes wrong!")
            running = false
        elseif (ev == "ab_new_train") then
            local act = false
            if (readdevice("ab_sr") > 0) then -- Train will stop
                if (readdevice("ab_sv") > 0) then -- Train will reverse
                    if (isfree[1]) then -- Train --> Way1
                        isfree[1] = false
                        revflag[1] = true

                        disabledevice("m6")
                        enabledevice("m1")
                        disabledevice("k1")
                        act = true
                    elseif (isfree[2]) then -- Train --> Way2
                        isfree[2] = false
                        revflag[2] = true

                        disabledevice("m6")
                        disabledevice("m1")
                        enabledevice("m2")
                        disabledevice("k2")
                        act = true
                    elseif (isfree[6]) then -- Train --> Way6
                        isfree[6] = false
                        revflag[6] = true

                        enabledevice("m6")
                        disabledevice("k6")
                        act = true
                    end
                else -- Train does not need reverse
                    if (isfree[1]) then -- Train --> Way1
                        isfree[1] = false
                        revflag[1] = false

                        disabledevice("m6")
                        enabledevice("m1")
                        disabledevice("k1")
                        act = true
                    elseif (isfree[2]) then -- Train --> Way2
                        isfree[2] = false
                        revflag[2] = false

                        disabledevice("m6")
                        disabledevice("m1")
                        enabledevice("m2")
                        disabledevice("k2")
                        act = true
                    end -- None-reverse train should not enter 6
                end
            else -- Train will pass
                if (isfree[3]) then -- Train --> Way3
                    isfree[3] = false
                    if (readdevice("ab_sv") > 0) then -- Train will reverse
                        revflag[3] = true
                    else
                        revflag[3] = false
                    end

                    disabledevice("m6")
                    disabledevice("m1")
                    disabledevice("m2")
                    disabledevice("k3")
                    act = true
                end
            end

            if (act) then
                trigger("ab_ko")
            else
                bus:push(ev)
            end
        elseif (ev == "ba_new_train") then
            local act = false
            if (isSideLineFree()) then -- Side line free, can move in.
                if (readdevice("ba_sr") > 0) then -- Train will stop
                    if (readdevice("ba_sv") > 0) then -- Train will reverse
                        if (isfree[5]) then -- Train --> Way5 (will reverse)
                            isfree[5] = false
                            revflag[5] = true

                            enabledevice("m4")
                            disabledevice("k5")
                            act = true
                        end
                    else -- Train does not need reverse
                        if (isfree[5]) then -- Train --> Way5 (will not reverse)
                            isfree[5] = false
                            revflag[5] = false

                            enabledevice("m4")
                            disabledevice("k5")
                            act = true
                        end
                    end
                else -- Train will pass
                    if (readdevice("ba_sv") > 0) then -- Train will reverse
                        if (isfree[5]) then -- Train --> Way5 (will reverse)
                            isfree[5] = false
                            revflag[5] = true

                            enabledevice("m4")
                            disabledevice("k5")
                            act = true
                        end
                    else -- Train does not need reverse
                        if (isfree[4]) then -- Train --> Way4 (not reverse)
                            isfree[4] = false
                            revflag[4] = false

                            disabledevice("m4")
                            disabledevice("k4")
                            act = true
                        elseif (isfree[5]) then -- Train --> Way5 (not reverse)
                            isfree[5] = false
                            revflag[5] = false

                            enabledevice("m4")
                            disabledevice("k5")
                            act = true
                        end
                    end
                end
            end

            if (act) then
                lockSideLine()
                trigger("ba_ko")
                unlockSideLine()
            else
                bus:push(ev)
            end
        elseif (ev == "s1_ready") then -- Add in-station timer
            addNormalStationTimer(1) --> s1_timeout
        elseif (ev == "s2_ready") then -- Add in-station timer
            addNormalStationTimer(2) --> s2_timeout
        elseif (ev == "s3_ready") then -- Judge or turn on timer
            addSimpleStationTimer(3)
            bus:push("s3_pending") --> s3_pending
        elseif (ev == "s4_ready") then
            addSimpleStationTimer(4)
            bus:push("s4_pending") --> s4_pending
        elseif (ev == "s5_ready") then -- Train must stay at way5 whether it wants to stop or not.
            addNormalStationTimer(5) --> s5_timeout
        elseif (ev == "s6_ready") then
            addNormalStationTimer(5) --> s6_timeout
        elseif (ev == "s1_timeout") then
            proc1236(1, ev)
        elseif (ev == "s2_timeout") then
            proc1236(2, ev)
        elseif (ev == "s3_pending") then
            proc1236(3, ev)
        elseif (ev == "s6_timeout") then
            proc1236(6, ev)
        elseif (ev == "s5_timeout") then
            local done = false
            if (revflag[5]) then -- Need reverse
                if (isfree[6]) then
                    isfree[6] = false
                    revflag[6] = false
                    enabledevice("m5")
                    disabledevice("k6")
                    done = true
                end -- If way6 is not free, we cannot reverse to it. (bang!)
            else -- Does not need reverse
                if (ba_time_out == 0 and timecnt[5] >= timecnt[4] and readdevice("ba_lout") > 0) then -- Can let go
                    disabledevice("m5")
                    done = true
                end -- Cannot move.
            end

            if (done) then
                startBATimer()
                stopTimer(5)
                trigger("k5")
                isfree[5] = true -- Mark way5 as free
            else
                bus:push(ev)
            end
        elseif (ev == "s4_pending") then
            local okay = false
            if (ba_time_out == 0 and readdevice("ba_lout") > 0) then -- Can let go
                if (isfree[5] or revflag[5] or (timecnt[4] >= timecnt[5])) then -- Way5 is free or Way5 will reverse
                    okay = true
                end
            end

            if (okay) then
                startBATimer()
                stopTimer(4)
                trigger("k4")
                isfree[4] = true -- Mark way 4 as free
            else
                bus:push(ev)
            end
        elseif (ev == "ab_time_out_needstop") then
            RemoveTimer(ab_timerid_out)
            ab_time_out = 0
        elseif (ev == "ba_time_out_needstop") then
            RemoveTimer(ba_timerid_out)
            ba_time_out = 0
        else -- Unknown event
            -- Debug: Output the event name
            print("Ignoring:", ev)
        end -- End of event patch
    end -- End of loop
    doCleanUp()
    doClearOutput()
end

-- Start-up script
print("Program Start")
TCSMain()
print("Program Stop")
