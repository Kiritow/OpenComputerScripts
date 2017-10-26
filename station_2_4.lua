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
        -- Critical error
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
    evl:push(ret)
end

local ab_available_1=true
local ab_available_2=true
local ab_timerid_1,ab_time_1=0,0
local ab_timerid_2,ab_time_2=0,0
local ab_timerid_out,ab_time_out=0,0

local ba_available_1=true
local ba_available_2=true
local ba_timerid_1,ba_time_1=0,0
local ba_timerid_2,ba_time_2=0,0
local ba_timerid_out,ba_time_out=0,0

local ebus=Queue.new()

local function doCheck()
    if(redin1==nil or redin2==nil or redin3==nil or redout1==nil or redout2==nil) then
        error("Check Failed. Please review your redstone configure")
    end
end

local function doInit()
    evl:push(AddEventListener("interrupted",
        function()
            ebus:push("stop")
        end))

    --- AB
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

    --- BA
    train_delegator("ba_st",
        function(from,to)
            if(from<to) then
                ebus:push("ba_new_train")
            else 
                ebus:push("ba_train_in")
            end
        end
    )
    train_delegator("ba_ins1",
        function(from,to)
            if(from<to) then
                ebus:push("ba_ins1_ready")
            else
                ebus:push("ba_ins1_leave")
            end
        end
    )
    train_delegator("ba_ins2",
        function(from,to)
            if(from<to) then
                ebus:push("ba_ins2_ready")
            else
                ebus:push("ba_ins2_leave")
            end
        end
    )
end

local function doCleanUp()
    while(evl:top()~=nil) do
        RemoveEventListener(evl:pop())
    end
end

local function doClearOutput()
    disabledevice("ab_ko")
    disabledevice("ab_m")
    disabledevice("ab_k1")
    disabledevice("ab_k2")
    disabledevice("ba_ko")
    disabledevice("ba_m")
    disabledevice("ba_k1")
    disabledevice("ba_k2")
end

local function TCSMain()
    doCheck()
    doClearOutput()
    doInit()
    print("TCS Started. Press Ctrl+C to stop.")
    -- Main Processing Loop
    local running=true
    while(running) do
        local ev="no_event"
        if(ebus:top()~=nil) then
            ev=ebus:pop() -- Notice: Event is already poped.
        end
        
        -- For Debug: Print Event Name
        if(ev~="no_event") then
            print(ev)
        end

        if(ev=="no_event") then
            os.sleep(0.5) -- No event, delay for more info
        elseif(ev=="stop") then
            running=false
        --- AB
        elseif(ev=="ab_new_train") then -- AB New Train
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
                    disabledevice("ab_m")
                    disabledevice("ab_k1")
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
                    enabledevice("ab_m")
                    disabledevice("ab_k2")
                end
            end

            if(act) then
                enabledevice("ab_ko")
                os.sleep(0.25)
                disabledevice("ab_ko")
            else -- Push Event back
                ebus:push(ev)
            end
        elseif(ev=="ab_ins1_ready") then
            if(ab_time_out==0 and ab_time_1>6 and ab_time_1>ab_time_2 and readdevice("ab_lout")>0) then
                RemoveTimer(ab_timerid_1)
                ab_time_1=0
                ab_available_1=true
                
                ab_time_out=1
                ab_timerid_out=AddTimer(1,
                    function()
                        ab_time_out=ab_time_out+1
                        if(ab_time_out==5) then
                            ebus:push("ab_time_out_needstop")
                        end
                    end,-1)
                
                enabledevice("ab_k1")
            else
                ebus:push(ev)
            end
        elseif(ev=="ab_ins2_ready") then
            if(ab_time_out==0 and ab_time_2>ab_time_1 and readdevice("ab_lout")>0) then
                RemoveTimer(ab_timerid_2)
                ab_time_2=0
                ab_available_2=true
                
                ab_time_out=1
                ab_timerid_out=AddTimer(1,
                    function()
                        ab_time_out=ab_time_out+1
                        if(ab_time_out==5) then
                            ebus:push("ab_time_out_needstop")
                        end
                    end,-1)
                
                enabledevice("ab_k2")
            else
                ebus:push(ev)
            end
        --- BA
        elseif(ev=="ba_new_train") then -- AB New Train
            local act=false
            if(readdevice("ba_sr")>0) then -- This train will coming into station
                if(ba_available_1) then 
                    ba_available_1=false
                    act=true
                    ba_time_1=0
                    ba_timerid_1=AddTimer(1,
                        function()
                            ba_time_1=ba_time_1+1
                        end,
                        -1)
                    disabledevice("ba_m")
                    disabledevice("ba_k1")
                end
            else -- This train will pass by station
                if(ba_available_2) then 
                    ba_available_2=false
                    act=true
                    ba_time_2=0
                    ba_timerid_2=AddTimer(1,
                        function()
                            ba_time_2=ba_time_2+1
                        end,
                        -1)
                    enabledevice("ba_m")
                    disabledevice("ba_k2")
                end
            end

            if(act) then
                enabledevice("ba_ko")
                os.sleep(0.25)
                disabledevice("ba_ko")
            else -- Push Event back
                ebus:push(ev)
            end
        elseif(ev=="ba_ins1_ready") then
            if(ba_time_out==0 and ba_time_1>6 and ba_time_1>ba_time_2 and readdevice("ba_lout")>0) then
                RemoveTimer(ba_timerid_1)
                ba_time_1=0
                ba_available_1=true
                
                ba_time_out=1
                ba_timerid_out=AddTimer(1,
                    function()
                        ba_time_out=ba_time_out+1
                        if(ba_time_out==5) then
                            ebus:push("ba_time_out_needstop")
                        end
                    end,-1)
                
                enabledevice("ba_k1")
            else
                ebus:push(ev)
            end
        elseif(ev=="ba_ins2_ready") then
            if(ba_time_out==0 and ba_time_2>ba_time_1 and readdevice("ba_lout")>0) then
                RemoveTimer(ba_timerid_2)
                ba_time_2=0
                ba_available_2=true
                
                ba_time_out=1
                ba_timerid_out=AddTimer(1,
                    function()
                        ba_time_out=ba_time_out+1
                        if(ba_time_out==5) then
                            ebus:push("ba_time_out_needstop")
                        end
                    end,-1)
                
                enabledevice("ba_k2")
            else
                ebus:push(ev)
            end
        elseif(ev=="ab_time_out_needstop") then
            RemoveTimer(ab_timerid_out)
            ab_time_out=0
        elseif(ev=="ba_time_out_needstop") then 
            RemoveTimer(ba_timerid_out)
            ba_time_out=0
        else -- Ignore unknown event
            -- Do nothing
        end

    end

    doCleanUp()
    doClearOutput()
end

-- Start-up script
print("Program Start")
TCSMain()
print("Program Stop")
