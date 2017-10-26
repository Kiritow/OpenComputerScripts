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
    ["ba_ko"]={redout4,sides.east},

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
local isfree={true,true,true,true,true,true} 
local timerid={0,0,0,0,0,0}
local timecnt={0,0,0,0,0,0}
local revflag={false,false,false,false,false,false}
local ab_timerid_out,ab_time_out=0,0
local ba_timerid_out,ba_time_out=0,0
local _side_line_free=true
local _side_line_hw=true

local function isSideLineFree()
    return _side_line_free and _side_line_hw
end

local function lockSideLine()
    _side_line_free=false
end

local function unlockSideLine()
    _side_line_free=true
end

local bus=Queue.new()

local function doInit()
    evl:push(AddEventListener("interrupted",
    function()
        bus:push("stop")
    end))

    train_delegator("ab_st",
        function(from,to)
            if(from<to) then
                bus:push("ab_new_train")
            end
        end)
    
    train_delegator("ba_st",
        function(from,to)
            if(from<to) then
                bus:push("ba_new_train")
            end
        end)

    train_delegator("st_l",
        function(from,to)
            if(from<to) then
                _side_line_hw=true
            else
                _side_line_hw=false
            end
        end)
    
    local smt={"s1","s2","s3","s4","s5","s6"}
    for k,v in pairs(smt) do
        train_delegator(v,
        function(from,to)
            if(from<to) then
                bus:push(v.. "_ready")
            end
        end)
    end
end

local function doCleanUp()
    while(evl:top()~=nil) do
        RemoveEventListener(evl:pop())
    end
end

local function doClearOutput()
    local smt=
    {"m1","m2","m3","m4","m5","m6","k1","k2","k3","k4","k5","k6","ab_ko","ba_ko"}

    for k,v in pairs(smt) do
        disabledevice(v)
    end
end

local function doCheck()
    for k,vt in pairs(redirect_tb) do
        if(vt[1]==nil) then
            error("Check Failed. Please review your redstone configure")
        end
    end

    print("Check Pass.")
end

local function TCSMain()
    doCheck()
    doClearOutput()
    doInit()

    print("TCS Started. Press Ctrl+C to stop.")

    -- Main Processing Loop
    local running=true
    while(running) do
        os.sleep(0.25) -- Shorter sleep, faster program.
        
        local ev="no_event"
        if(ebus:top()~=nil) then
            ev=ebus:pop() -- Notice: Event is already poped.
        end
        
        -- For Debug: Print Event Name
        if(ev~="no_event") then
            print(ev)
        end

        if(ev=="no_event") then
            -- No event, no action.
        elseif(ev=="stop") then
            running=false
        elseif(ev=="ab_new_train") then
            local act=false
            if(readdevice("ab_sr")>0) then -- Train will stop
                if(readdevice("ab_sv")>0) then -- Train will reverse
                    if(isfree[1]) then -- Train --> Way1
                        isfree[1]=false
                        revflag[1]=true

                        disabledevice("m6")
                        enabledevice("m1")
                        disabledevice("k1")
                        act=true
                    elseif(isfree[2]) then -- Train --> Way2
                        isfree[2]=false
                        revflag[2]=true

                        disabledevice("m6")
                        disabledevice("m1")
                        enabledevice("m2")
                        disabledevice("k2")
                        act=true
                    elseif(isfree[6]) then -- Train --> Way6
                        isfree[6]=false
                        revflag[6]=true
                        
                        enabledevice("m6")
                        disabledevice("k6")
                        act=true
                    end
                else -- Train does not need reverse
                    if(isfree[1]) then -- Train --> Way1
                        isfree[1]=false
                        revflag[1]=false

                        disabledevice("m6")
                        enabledevice("m1")
                        disabledevice("k1")
                        act=true
                    elseif(isfree[2]) then -- Train --> Way2
                        isfree[2]=false
                        revflag[2]=false

                        disabledevice("m6")
                        disabledevice("m1")
                        enabledevice("m2")
                        disabledevice("k2")
                        act=true
                    end -- None-reverse train should not enter 6
                end
            else -- Train will pass
                if(isfree[3]) then -- Train --> Way3
                    isfree[3]=false
                    if(readdevice("ab_sv")>0) then -- Train will reverse
                        revflag[3]=true
                    else
                        revflag[3]=false
                    end
                    
                    disabledevice("m6")
                    disabledevice("m1")
                    disabledevice("m2")
                    disabledevice("k3")
                    act=true
                end
            end

            if(act) then
                enabledevice("ab_ko")
                os.sleep(0.25)
                disabledevice("ab_ko")
            else
                bus:push(ev)
            end
        elseif(ev=="ba_new_train") then
            local act=false
            if(readdevice("ba_sr")>0) then -- Train will stop
                if(readdevice("ba_sv")>0) then -- Train will reverse
                    if(isfree[5]) then -- Train --> Way5 (will reverse)
                        isfree[5]=false
                        revflag[5]=true

                        enabledevice("m4")
                        disabledevice("k5")
                        act=true
                    end
                else -- Train does not need reverse
                    if(isfree[5]) then -- Train --> Way5 (will not reverse)
                        isfree[5]=false
                        revflag[5]=false

                        enabledevice("m4")
                        disabledevice("k5")
                        act=true
                    end
                end
            else -- Train will pass
                if(readdevice("ba_sv")>0) then -- Train will reverse
                    if(isfree[5]) then -- Train --> Way5 (will not reverse)
                        isfree[5]=false
                        revflag[5]=true

                        enabledevice("m4")
                        disabledevice("k5")
                        act=true
                    end
                else -- Train does not need reverse
                    if(isfree[4]) then
                        isfree[4]=false
                        revflag[4]=false
                        
                        disabledevice("m4")
                        disabledevice("k4")
                        act=true
                    elseif(isfree[5]) then 
                        isfree[5]=false
                        revflag[5]=false

                        enabledevice("m4")
                        disabledevice("k5")
                        act=true
                    end
                end
            end
            
            if(act) then
                enabledevice("ba_ko")
                os.sleep(0.25)
                disabledevice("ba_ko")
            else
                bus:push(ev)
            end
        elseif(ev=="s1_ready") then -- Add in-station timer
            timecnt[1]=1
            timerid[1]=AddTimer(1,
                function()
                    timecnt[1]=timecnt[1]+1
                    if(timecnt[1]==5) then
                        bus:push("s1_timeout")
                    end
                end,-1)
        elseif(ev=="s2_ready") then -- Add in-station timer
            timecnt[2]=1
            timerid[2]=AddTimer(1,
                function()
                    timecnt[2]=timecnt[2]+1
                    if(timecnt[2]==5) then
                        bus:push("s2_timeout")
                    end
                end,-1)
        elseif(ev=="s3_ready") then -- Judge or turn on timer
            local needtimer=false
            if(revflag[3]) then -- Need rev. Go line 4 or line 5
                if(isfree[4]) then -- Way 3 --> Way 4
                    if(isSideLineFree()) then
                        isfree[4]=false
                        revflag[4]=false
                        
                        lockSideLine()
                        disabledevice("m3")
                        disabledevice("m4")
                        disabledevice("k4")
                        enabledevice("k3")
                        os.sleep(0.25)
                        disabledevice("k3")
                        os.sleep(3)
                        unlockSideLine()
                    else
                        needtimer=true
                    end
                elseif(isfree[5]) then -- Way 3 --> Way 5
                    if(isSideLineFree()) then
                        isfree[5]=false
                        revflag[5]=false
                        lockSideLine()
                        disabledevice("m3")
                        enabledevice("m4")
                        disabledevice("k5")
                        enabledevice("k3")
                        os.sleep(0.25)
                        disabledevice("k3")
                        os.sleep(3)
                        unlockSideLine()
                    else
                        needtimer=true
                    end
                end
            else -- way 3 does not need rev
                if(isSideLineFree()) then
                    lockSideLine()
                    enabledevice("m3")
                    enabledevice("k3")
                    os.sleep(0.25)
                    disabledevice("k3")
                    os.sleep(3)
                    unlockSideLine()
                else
                    needtimer=true
                end
            end
            if(needtimer) then -- We need a timer... (can't move, sad >_<)
                timecnt[3]=1
                timerid[3]=AddTimer(1,
                    function()
                        timecnt[3]=timecnt[3]+1
                    end,-1)
                bus:push("s3_pending") -- Tell scheduler Way 3 is pending
            else -- Yeah! Moved directly! Now we mark way 3 as free
                isfree[3]=true
            end
        elseif(ev=="s4_ready") then
            local act=false
            if(ba_time_out==0 and readdevice("ba_lout")>0) then -- Can let go
                if(isfree[5] or revflag[5]==true) then -- Way5 is free or Way5 will reverse
                    act=true
                end
            end

            if(act) then
                -- Add BA Timer
                ba_time_out=1
                ba_timerid_out=AddTimer(1,
                    function()
                        ba_time_out=ba_time_out+1
                        if(ba_time_out==8) then
                            bus:push("ba_time_out_needstop")
                        end
                    end,-1)
                enabledevice("k4")
                os.sleep(0.25)
                disabledevice("k4")
                isfree[4]=true
            else
                timecnt[4]=0
                timerid[4]=AddTimer(1,
                    function()
                        timecnt[4]=timecnt[4]+1
                    end,-1)
                bus:push("s4_pending") -- Tell scheduler Way 4 is pending
            end
        elseif(ev=="s5_ready") then -- Train must stay at way5 whether it wants to stop or not.
            timecnt[5]=1
            timerid[5]=AddTimer(1,
                function()
                    timecnt[5]=timecnt[5]+1
                    if(timecnt[5]==5) then
                        bus:push("s5_timeout")
                    end
                end,-1)
        elseif(ev=="s6_ready") then
            timecnt[6]=1
            timerid[6]=AddTimer(1,
                function()
                    timecnt[6]=timecnt[6]+1
                    if(timecnt[6]==5) then
                        bus:push("s6_timeout")
                    end
                end,-1)
        elseif(ev=="s1_timeout") then
            local done=false
            if(isSideLineFree()) then -- Side line must be free(or we can't move at all)
                if(revflag[1]) then -- Way1 need reverse
                    if(isfree[4]) then -- Way 1 --> Way 4
                        done=true
                        lockSideLine()
                        isfree[4]=false
                        revflag[4]=false
                        disabledevice("m3")
                        disabledevice("m4")
                        disabledevice("k4")
                        
                        enabledevice("k1")
                        os.sleep(3)
                        disabledevice("k1")
                        
                        unlockSideLine()
                    elseif(isfree[5]) then --- Way1 --> Way5
                        done=true
                        lockSideLine()
                        isfree[5]=false
                        revflag[5]=false
                        disabledevice("m3")
                        enabledevice("m4")
                        disabledevice("k5")

                        enabledevice("k1")
                        os.sleep(3)
                        disabledevice("k1")
                        
                        unlockSideLine()
                    end
                else -- Way 1 does not need reverse
                    if(readdevice("ab_lout")>0) then -- Can move to next station (B)
                        done=true
                        lockSideLine()
                        enabledevice("m3")

                        enabledevice("k1")
                        os.sleep(3)
                        disabledevice("k1")
                        
                        unlockSideLine()
                    end
                end
            end

            if(done) then -- Clear way1
                isfree[1]=true
            else
                bus:push(ev)
            end
        elseif(ev=="s2_timeout") then
            local done=false
            if(isSideLineFree()) then -- Side line must be free(or we can't move at all)
                if(revflag[2]) then -- Way2 need reverse
                    if(isfree[4]) then -- Way 2 --> Way 4
                        done=true
                        lockSideLine()
                        isfree[4]=false
                        revflag[4]=false
                        disabledevice("m3")
                        disabledevice("m4")
                        disabledevice("k4")
                        
                        enabledevice("k2")
                        os.sleep(3)
                        disabledevice("k2")
                        
                        unlockSideLine()
                    elseif(isfree[5]) then --- Way2 --> Way5
                        done=true
                        lockSideLine()
                        isfree[5]=false
                        revflag[5]=false
                        disabledevice("m3")
                        enabledevice("m4")
                        disabledevice("k5")

                        enabledevice("k2")
                        os.sleep(3)
                        disabledevice("k2")
                        
                        unlockSideLine()
                    end
                else -- Way 2 does not need reverse
                    if(readdevice("ab_lout")>0) then -- Can move to next station (B)
                        done=true
                        lockSideLine()
                        enabledevice("m3")

                        enabledevice("k2")
                        os.sleep(3)
                        disabledevice("k2")
                        
                        unlockSideLine()
                    end
                end
            end

            if(done) then -- Clear way2
                isfree[2]=true
            else
                bus:push(ev)
            end
        elseif(ev=="s6_timeout") then
            local done=false
            if(isSideLineFree()) then -- Side line must be free(or we can't move at all)
                if(revflag[6]) then -- Way6 need reverse
                    if(isfree[4]) then -- Way 6 --> Way 4
                        done=true
                        lockSideLine()
                        isfree[4]=false
                        revflag[4]=false
                        disabledevice("m3")
                        disabledevice("m4")
                        disabledevice("k4")
                        
                        enabledevice("k6")
                        os.sleep(3)
                        disabledevice("k6")
                        
                        unlockSideLine()
                    elseif(isfree[5]) then --- Way6 --> Way5
                        done=true
                        lockSideLine()
                        isfree[5]=false
                        revflag[5]=false
                        disabledevice("m3")
                        enabledevice("m4")
                        disabledevice("k5")

                        enabledevice("k6")
                        os.sleep(3)
                        disabledevice("k6")
                        
                        unlockSideLine()
                    end
                else -- Way 6 does not need reverse
                    if(readdevice("ab_lout")>0) then -- Can move to next station (B)
                        done=true
                        lockSideLine()
                        enabledevice("m3")

                        enabledevice("k6")
                        os.sleep(3)
                        disabledevice("k6")
                        
                        unlockSideLine()
                    end
                end
            end

            if(done) then -- Clear way6
                isfree[6]=true
            else
                bus:push(ev)
            end
        elseif(ev=="s5_timeout") then
            local done=false
            if(revflag[5]) then -- Need reverse
                if(isfree[6]) then
                    isfree[6]=false
                    revflag[6]=false
                    enabledevice("m5")
                    disabledevice("k6")

                    enabledevice("k5")
                    os.sleep(0.25)
                    disabledevice("k5")
                    
                    done=true
                end -- If way6 is not free, we cannot reverse to it. (bang!)
            else -- Does not need reverse
                if(ba_time_out==0 and readdevice("ba_lout")>0) then -- Can let go
                    if(isfree[4] or timecnt[4]==0 or timecnt[5]>timecnt[4]) then -- If Way4 is free, or way4 is not ready, or way5 wait longer
                        ba_time_out=1
                        ba_timerid_out=AddTimer(1,
                            function()
                                ba_time_out=ba_time_out+1
                                if(ba_time_out==8) then
                                    bus:push("ba_time_out_needstop")
                                end
                            end,
                        -1)
                        disabledevice("m5")
                        enabledevice("k5")
                        os.sleep(0.25)
                        disabledevice("k5")

                        done=true
                    end -- We just cannot move. (We must wait!)
                end -- Cannot move at all.
            end
            if(done) then
                isfree[5]=true -- Mark way5 as free
            else
                bus:push(ev)
            end
        elseif(ev=="s3_pending") then
            local done=false
            if(revflag[3]) then -- Need rev. Go line 4 or line 5
                if(isfree[4]) then -- Way 3 --> Way 4
                    if(isSideLineFree()) then
                        isfree[4]=false
                        revflag[4]=false
                        
                        lockSideLine()
                        disabledevice("m3")
                        disabledevice("m4")
                        disabledevice("k4")
                        enabledevice("k3")
                        os.sleep(0.25)
                        disabledevice("k3")
                        os.sleep(3)
                        unlockSideLine()
                        done=true
                    end
                elseif(isfree[5]) then -- Way 3 --> Way 5
                    if(isSideLineFree()) then
                        isfree[5]=false
                        revflag[5]=false
                        lockSideLine()
                        disabledevice("m3")
                        enabledevice("m4")
                        disabledevice("k5")
                        enabledevice("k3")
                        os.sleep(0.25)
                        disabledevice("k3")
                        os.sleep(3)
                        unlockSideLine()
                        done=true
                    end
                end
            else -- way 3 does not need rev
                if(isSideLineFree()) then
                    lockSideLine()
                    enabledevice("m3")
                    enabledevice("k3")
                    os.sleep(0.25)
                    disabledevice("k3")
                    os.sleep(3)
                    unlockSideLine()
                    done=true
                end
            end
            if(done) then -- mark way 3 as free
                isfree[3]=true
            else 
                bus:push(ev)
            end
        elseif(ev=="s4_pending") then 
            local okay=false
            if(ba_time_out==0 and readdevice("ba_lout")>0) then -- Can let go
                if(isfree[5] or revflag[5]==true) then -- Way5 is free or Way5 will reverse
                    okay=true
                end
            end

            if(okay) then
                -- Add BA Timer
                ba_time_out=1
                ba_timerid_out=AddTimer(1,
                    function()
                        ba_time_out=ba_time_out+1
                        if(ba_time_out==8) then
                            bus:push("ba_time_out_needstop")
                        end
                    end,-1)
                enabledevice("k4")
                os.sleep(0.25)
                disabledevice("k4")
                isfree[4]=true
            else
                bus:push(ev)
            end
        else -- Unknown event
            -- Debug: Output the event name
            print("Ignoring:",ev)
        end -- End of event patch
    end -- End of loop
    doCleanUp()
    doClearOutput()
end

-- Start-up script
print("Program Start")
TCSMain()
print("Program Stop")
