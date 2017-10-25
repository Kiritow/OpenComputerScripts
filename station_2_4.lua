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

local function doInit()
    train_delegator("ab_st",
        function(from,to)
            if(from<to) then
                print("enable")
                enabledevice("ab_ko")
            else 
                print("disable")
                disabledevice("ab_ko")
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
    WaitEvent("interrupted")
    doCleanUp()
end

-- Start-up script
print("Program Start")
TCSMain()
print("Program Stop")
