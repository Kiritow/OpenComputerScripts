--[[
    Station 2/6 Standard Schedule Program
]]

require("libevent")
require("util")
require("checkarg")
require("queue")
local sides=require("sides")

-- Config your update functions here (Do not change variable name)
local redin1 = proxy("redstone", "")
local redin2 = proxy("redstone", "")
local redin3 = proxy("redstone", "")
local redin4 = proxy("redstone", "")
local redout1 = proxy("redstone", "")
local redout2 = proxy("redstone", "")
local redout3 = proxy("redstone", "")
local redout4 = proxy("redstone", "")

-- Redirect Table
local redirect_tb=
{
    ["ab_st"]={redin1,sides.north},
    ["ab_sr"]={redin1,sides.east},
    ["ab_sv"]={redin1,sides.south},
    ["ab_lout"]={redin1,sides.west},

    ["ba_st"] = {redin2,sides.north},
    ["ba_sr"] = {redin2,sides.east},
    ["ba_sv"]={redin2,sides.south},
    ["ba_lout"] = {redin2,sides.west},

    -- ins: Inside station sensor
    ["s1"] = {redin3,sides.north},
    ["s2"] = {redin3,sides.east},
    ["s3"] = {redin3,sides.south},
    ["s4"] = {redin3,sides.west},
    
    ["s5"]={redin4,sides.north},
    ["s6"]={redin4,sides.east},
    ["st_l"]={redin4,sides.south},
    
    
    -- Output
    ["m1"]={redout1,sides.north},
    ["m2"]={redout1,sides.east},
    ["m3"]={redout1,sides.south},
    ["m4"]={redout1,sides.west},
    
    ["m5"]={redout2,sides.north},
    ["m6"]={redout2,sides.east},
    ["k1"]={redout2,sides.south},
    ["k2"]={redout2,sides.west},

    ["k3"]={redout3,sides.north},
    ["k4"]={redout3,sides.east},
    ["k5"]={redout3,sides.south},
    ["k6"]={redout3,sides.west},
    
    ["ab_ko"]={redout4,sides.north},
    ["ba_ko"]={redout4,sides.east}

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
        -- Critical error
        error("failed to read device input")
    end
end

local evl=Queue.new()

local function train_delegator(Name,callback_func)
    evl:push(AddEventListener("redstone_changed",
        function(ev,dev,sd,from,to)
            if(getNameFromRaw(dev,sd)==Name) then
                callback_func(from,to)
            end
        end))
end

-- Data for 6 ways.
local freeway={true,true,true,true,true,true} 
local timerid={0,0,0,0,0,0}
local timecnt={0,0,0,0,0,0}
local revflag={0,0,0,0,0,0}
local ab_timerid_out,ab_time_out=0,0
local ba_timerid_out,ba_time_out=0,0

local bus=Queue.new()

local function doInit()
    train_delegator("ab_st",
        function(from,to)
            if(from<to) then
                bus:push("ab_new_train")
            end
        end)
    train_delegator("s1",
        function(from,to)
            if(from<to) then
                bus:push("s1_ready")
            end
        end)
    
end