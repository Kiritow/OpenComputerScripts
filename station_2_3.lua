--[[
Station 2/3 Schedule Program
]]
require("util")
require("libevent")
require("checkarg")
local sides = require("sides")

-- Config your update functions here (Do not change function name)
local redin1 = proxy("redstone", "")
local redin2 = proxy("redstone", "")
local redout1 = proxy("redstone", "")
local redout2 = proxy("redstone", "")

--[[
Redstone Signals
Direction_[Type][Info]: number
]]
local ab_st, ab_sr, ab_lin, ab_lout
local ba_st, ba_sr, ba_lin, ba_lout

local function updateRedstoneInput()
    ab_st = redin1.getInput(sides.north)
    ab_sr = redin1.getInput(sides.east)
    ba_st = redin1.getInput(sides.south)
    ba_sr = redin1.getInput(sides.west)
    ab_lin = redin2.getInput(sides.north)
    ab_lout = redin2.getInput(sides.east)
    ba_lin = redin2.getInput(sides.south)
    ba_lout = redin2.getInput(sides.west)
end

-- Redirect Table
local redirect_tb=
{
    ["ab_st"]={redin1,sides.north},
    ["ab_sr"]={redin1,sides.east},
    ["ba_st"]={redin1,sides.south},
    ["ba_sr"]={redin1,sides.west},
    ["ab_lin"] = {redin2,sides.north},
    ["ab_lout"] = {redin2,sides.east},
    ["ba_lin"] = {redin2,sides.south},
    ["ba_lout"] = {redin2,sides.west},

    ["ab_ko"]={redout1,sides.north},
    ["ab_m"]={redout1,sides.east},
    ["ab_ks"]={redout1,sides.south},
    ["mid_ka"]={redout1,sides.west},
    ["ba_ko"]={redout2,sides.north},
    ["ba_m"]={redout1,sides.east},
    ["ba_ks"]={redout1,sides.south},
    ["mid_kb"]={redout1,sides.west},

    ["last_unused"]={"unused",sides.north}
}

local function getNameFromRaw(Device,Side)
    for k,t in pairs(redirect_tb) do 
        if(t[1]==Device and t[2]==Side) then 
            return k
        end
    end

    return nil
end

local function getRawFromName(Name)
    return redirect_tb[Name][1],redirect_tb[Name][2]
end

-- Internal Schedule Status (Notice: Program must start without any trains in station)
local mid_direction
local ab_station_time = 0
local ba_station_time = 0
local mid_time = 0
local ab_exit_time = 0
local ba_exit_time = 0
local midab_exit_time = 0 -- Mid needs cool
local midba_exit_time = 0

-- NOOP print function (for release use)
local function noop_print(...)
end

-- Debug Output
local dprint = print

local function debugOutputInfo()
    dprint(
        "ab_st",ab_st,
        "ab_sr",ab_sr,
        "ba_st",ba_st,
        "ba_sr",ba_sr,
        "ab_lin",ab_lin,
        "ab_lout",ab_lout,
        "ba_lin",ba_lin,
        "ba_lout",ba_lout
    )
    dprint(
        "mid_direction",mid_direction,
        "ab_station_time",ab_station_time,
        "ba_station_time",ba_station_time,
        "mid_time",mid_time,
        "ab_exit_time",ab_exit_time,
        "ba_exit_time",ba_exit_time,
        "midab_exit_time",midab_exit_time,
        "midba_exit_time",midba_exit_time
    )
end

--[[
    Internal Functions
]]
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

-- Notice: RedTick=0.1s GameTick=0.05s
local function delay(loop)
    local perloop=1

    if (loop*perloop < 0.1) then
        loop=0.1/perloop;
    end -- Less than 0.1s is useless
    
    os.sleep(loop * perloop)
end

local running = true

local function clearRedstoneOutput()
    disabledevice("ab_ko")
    disabledevice("ab_m")
    disabledevice("ab_ks")
    disabledevice("ba_ko")
    disabledevice("ba_m")
    disabledevice("ba_ks")
    disabledevice("mid_ka")
    disabledevice("mid_kb")
end

local function doCheck()
    if(redin1==nil or redin2==nil or redout1==nil or redout2==nil) then
        error("Check Failed. Please fill your redstone IO configure")
    end

    if(not (redin1 == redin2 and redin2 == redout1 and redout1 == redout2) ) then 
        -- Check OK
        print("BeforeCheck Pass.")
    else
        error("Check Failed. Please check your redstone IO configure.")
    end
end

local function doInit()
    -- Flash output to zero.
    clearRedstoneOutput()
    AddEventListener(
        "key_down",
        function(Event,Addr,InputChar)
            if(InputChar==32) then -- Pressed Space
                running = false
                print("Interrupt Signal Received.")
                return false --Unregister event listener itself
            end
        end
    )

    running = true
end

-- Main Program
local function TCSMain()
    doCheck() --TODO
    doInit()
    while running do
        -- Flush input
        updateRedstoneInput()

        -- Update status
        if (ab_station_time > 0) then
            ab_station_time = ab_station_time + 1
        end
        if (ba_station_time > 0) then
            ba_station_time = ba_station_time + 1
        end
        if (mid_time > 0) then
            mid_time = mid_time + 1
        end
        if (ab_exit_time > 0) then
            ab_exit_time = ab_exit_time + 1
            if (ab_exit_time > 10) then -- Exit will reset in 10 loops (5seconds)
                ab_exit_time = 0
            end
        end
        if (ba_exit_time > 0) then
            ba_exit_time = ba_exit_time + 1
            if (ba_exit_time > 10) then -- Exit will reset in 10 loops (5seconds)
                ba_exit_time = 0
            end
        end
        if (midab_exit_time > 0) then
            midab_exit_time = midab_exit_time + 1
            if (midab_exit_time > 8) then -- MidAB will cool in 8 loops (4seconds)
                midab_exit_time = 0
            end
        end
        if (midba_exit_time > 0) then
            midba_exit_time = midba_exit_time + 1
            if (midba_exit_time > 8) then -- MidBA will cool in 8 loops (4seconds)
                midba_exit_time = 0
            end
        end

        -- Judge Incoming bus.
        local ctflag=false

        if (ab_st > 0) then -- New incoming bus from A to B
            if (ab_sr > 0) then -- This bus want to stop
                if (ab_station_time == 0) then -- If AB Station is free
                    dprint("A-->B Train In")
                    disabledevice("ab_ks") -- disabe to let it stop
                    disabledevice("ab_m") -- disable to allow incoming to station
                    enabledevice("ab_ko") -- enable to allow incoming
                    delay(0.5) -- delay 50% loop time
                    disabledevice("ab_ko") -- disable to block another train
                    ab_station_time = 1 -- Start Time Counter
                    ctflag=true
                else -- AB Station is not free
                    -- This train should wait outside the station
                    dprint("A-->B Train Pending")
                end
            else -- This bus want to pass by
                if (mid_time == 0 and midba_exit_time == 0) then -- Mid is free and MidBA is cool
                    dprint("A-->Mid Train In")
                    enabledevice("ab_m") -- enable motor to let it pass.
                    enabledevice("mid_ka") -- enable switch from A
                    disabledevice("mid_kb") -- disable switch to B
                    mid_direction = "ab"
                    enabledevice("ab_ko") -- enable to allow incoming
                    delay(0.5)
                    disabledevice("ab_ko") -- disable to block another train
                    mid_time = 1 -- Start time counter
                    ctflag=true
                else -- Mid is busy
                    -- This train should wait outside the station
                    dprint("A-->Mid Train Pending")
                end
            end
        end

        if (ba_st > 0) then -- New incoming bus from B to A
            if (ba_sr > 0) then -- This bus want to stop
                if (ba_station_time == 0) then -- If BA Station is free
                    dprint("B-->A Train In")
                    disabledevice("ba_ks") -- disable to let it stop
                    disabledevice("ba_m") -- disable to allow incoming to station
                    enabledevice("ba_ko") -- enable to allow incoming
                    delay(0.5)
                    disabledevice("ba_ko") -- disable to block another train
                    ba_station_time = 1 -- Start Time Counter
                    ctflag=true
                else -- BA Station is not free
                    -- This train should wait outside the station
                    dprint("B-->A Train Pending")
                end
            else -- This bus want to pass by
                if (mid_time == 0 and midab_exit_time == 0) then -- Mid is free and MidAB is free
                    dprint("B-->Mid Train In")
                    enabledevice("ba_m")
                     -- enable motor to let it pass.
                    disabledevice("mid_ka")
                    enabledevice("mid_kb")
                    enabledevice("ba_ko") -- enable to allow incoming
                    delay(0.5)
                    disabledevice("ba_ko") -- disable to block another train
                    mid_direction = "ba"
                    mid_time = 1
                    ctflag=true
                else -- Mid is busy
                    -- This train should wait outside the station
                    dprint("B-->Mid Train Pending")
                end
            end
        end

        if(not ctflag) then -- No Train Coming In
            if (ab_lout > 0 and ab_exit_time == 0) then -- AB next free
                -- Judge which train should pass.
                if (ab_station_time > 16 and (mid_time > 0 and mid_direction == "ab")) then -- Two Trains
                    if (ab_station_time > mid_time) then -- StationTrain wait longer.
                        dprint("A-->B Train Out")
                        ab_station_time = 0 -- Stop counter
                        enabledevice("ab_ks") -- enable swith to let it go
                        ab_exit_time = 1 -- Start Exit Counter
                    else -- MidTrain wait longer
                        dprint("Mid-->B Train out")
                        mid_time = 0 -- Stop Counter
                        enabledevice("mid_kb") -- enable switch
                        ab_exit_time = 1 -- Start Exit Counter
                        midab_exit_time = 1 -- Start mid exit counter
                    end
                elseif (ab_station_time > 16) then --Only Station Train
                    dprint("A-->B Train Out")
                    ab_station_time = 0 -- Stop Counter
                    enabledevice("ab_ks")
                    ab_exit_time = 1 -- Start exit counter
                elseif (mid_time > 0 and mid_direction == "ab") then -- Only Mid Train
                    dprint("Mid-->B Train Out")
                    mid_time = 0 -- Stop counter
                    enabledevice("mid_kb")
                    ab_exit_time = 1 -- Start exit counter
                end -- No train, do nothing
            end -- End of AB judge

            if (ba_lout > 0 and ba_exit_time == 0) then -- BA next free
                -- Judge which train should pass.
                if (ba_station_time > 16 and (mid_time > 0 and mid_direction == "ba")) then -- Two Trains
                    if (ba_station_time > mid_time) then -- StationTrain wait longer.
                        dprint("B-->A Train Out")
                        ba_station_time = 0 -- Stop counter
                        enabledevice("ba_ks") -- enable swith to let it go
                        ba_exit_time = 1 -- Start exit counter
                    else -- MidTrain wait longer
                        dprint("Mid-->A Train Out")
                        mid_time = 0 -- Stop Counter
                        enabledevice("mid_ka")
                        ba_exit_time = 1 -- Start Counter
                    end
                elseif (ba_station_time > 16) then --Only Station Train
                    dprint("B-->A Train Out")
                    ba_station_time = 0 -- Stop counter
                    enabledevice("ba_ks") -- enable swith to let it go
                    ba_exit_time = 1 -- Start exit counter
                elseif (mid_time > 0 and mid_direction == "ba") then -- Only Mid Train
                    dprint("Mid-->A Train Out")
                    mid_time = 0 -- Stop Counter
                    enabledevice("mid_ka")
                    ba_exit_time = 1 -- Start Counter
                end -- No train, do nothing
            end -- End of BA judge
        end -- End of ctflag

        debugOutputInfo()

        -- Sleep for next loop
        dprint("==========")
        delay(1)
    end -- End of while loop
    -- Block All Trains on terminate.
    clearRedstoneOutput()
end

print("Train Control System Start!")
TCSMain()
print("Train Control System Stop!")
