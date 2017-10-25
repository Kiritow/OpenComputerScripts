--[[
    Station 2/4 Standard Schedule Program
]]

require("libevent")
require("util")
require("checkarg")
require("queue")
local sides=require("sides")

-- Config your update functions here (Do not change function name)
local redin1 = proxy("redstone", "")
local redin2 = proxy("redstone", "")
local redin3 = proxy("redstone", "")
local redout1 = proxy("redstone", "")
local redout2 = proxy("redstone", "")

-- Redirect Table
local redirect_tb=
{
    ["ab_st"]={redin1,sides.north},
    ["ab_sr"]={redin1,sides.east},
    ["ab_lout"]={redin1,sides.south},

    ["ba_st"] = {redin2,sides.north},
    ["ba_sr"] = {redin2,sides.east},
    ["ba_lout"] = {redin2,sides.south},

    -- ins: Inside station sensor
    ["ab_ins1"] = {redin3,sides.north},
    ["ab_ins2"] = {redin3,sides.east},
    ["ba_ins1"] = {redin3,sides.south},
    ["ba_ins2"] = {redin3,sides.west},

    ["ab_ko"]={redout1,sides.north},
    ["ab_m"]={redout1,sides.east},
    ["ab_k1"]={redout1,sides.south},
    ["ab_k2"]={redout1,sides.west},

    ["ba_ko"]={redout2,sides.north},
    ["ba_m"]={redout2,sides.east},
    ["ba_k1"]={redout2,sides.south},
    ["ba_k2"]={redout2,sides.west},

    ["last_unused"]={"unused",sides.north}
}

local function getNameFromRaw(Device,Side)
    for k,t in pairs(redirect_tb) do 
        if(t[1].address == Device and t[2]==Side) then 
            return k
        end
    end

    return nil
end

local function getRawFromName(Name)
    return redirect_tb[Name][1],redirect_tb[Name][2]
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
    local d,s=getRawFromName(Name)
    if(d~=nil and s~=nil) then
        return d.getInput(s)
    else
        error("failed to read device input")
    end
end

local evl=Queue.new()

local function train_delegator(Name,callback_func)
    local ret=AddEventListener("redstone_changed",
        function(ev,dev,sd,from,to)
            if(getNameFromRaw(dev,sd)==Name) then
                callback_func(from,to)
            end
        end)
    print("Delegator: ",ret)
    evl:push(ret)
end

local ab_available_1=true
local ab_available_2=true
local ab_timerid_1,ab_time_1
local ab_timerid_2,ab_time_2

local ebus=Queue.new()

local function doInit()
    train_delegator("ab_st",
        function(from,to)
            if(from<to) then
                ebus:push("ab_new_train")
            else 
                ebus:push("ab_train_in")
            end
        end
    )
    train_delegator("ab_ins1",
        function(from,to)
            if(from<to) then
                ebus:push("ab_ins1_ready")
            else
                ebus:push("ab_ins1_leave")
            end
        end
    )
    train_delegator("ab_ins2",
        function(from,to)
            if(from<to) then
                ebus:push("ab_ins2_ready")
            else
                ebus:push("ab_ins2_leave")
            end
        end
    )
end

local function doCleanUp()
    while(evl:top()~=nil) do
        RemoveEventListener(evl:pop())
    end
end

local function TCSMain()
    doInit()
    print("TCS Started. Press Ctrl+C to stop.")
    -- Main Processing Loop
    while(true) do
        local ev="no_event"
        if(ebus:top()~=nil) then
            ev=ebus:pop() -- Notice: Event is already poped.
        end

        if(ev=="no_event") then
            os.sleep(0.5) -- No event, delay for more info
        elseif(ev=="ab_new_train") then
            local act=false
            if(readdevice("ab_sr")>0) then -- This train will coming into station
                if(ab_available_1) then 
                    ab_available_1=false
                    act=true
                    ab_time_1=0
                    ab_timerid_1=AddTimer(1,
                        function()
                            ab_time_1=ab_time_1+1
                        end,
                        -1)
                end
            else -- This train will pass by station
                if(ab_available_2) then 
                    ab_available_2=false
                    act=true
                    ab_time_2=0
                    ab_timerid_2=AddTimer(1,
                        function()
                            ab_time_2=ab_time_2+1
                        end,
                        -1)
                end
            end

            if(act) then
                enabledevice("ab_ko")
                os.sleep(0.25)
                disabledevice("ab_ko")
            else -- Push Event back
                ebus:push(ev)
            end
        else -- Ignore unknown event
            -- Do nothing
        end

    end

    doCleanUp()
end

-- Start-up script
print("Program Start")
TCSMain()
print("Program Stop")
