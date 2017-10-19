--[[
Station 2/3 Schedule Program
]]

require("util")
local sides=require("sides")
local event=require("event")
--[[
Redstone Signals
Direction_[Type][Info]: number
]]
local ab_st,ab_sr,ab_lin,ab_lout
local ba_st,ba_sr,ba_lin,ba_lout

local ab_ko,ab_m,ab_ks=0,0,0
local ba_ko,ba_m,ba_ks=0,0,0
local mid_ka,mid_kb=0,0

-- Config your update functions here (Do not change function name)
local redin1=proxy("redstone","")
local redin2=proxy("redstone","")
local redout1=proxy("redstone","")
local redout2=proxy("redstone","")

local function updateRedstoneInput()

end

local function updateRedstoneOutput()

end

-- Internal Schedule Status (Notice: Program must start without any trains in station)
local mid_direction
local ab_station_time=0
local ba_station_time=0
local mid_time=0
local ab_exit_time=0
local ba_exit_time=0

--[[
    Internal Functions
]]

local function doInit()
    -- Flash output to zero.
    updateRedstoneOutput()
end

-- Main Program
local function main()
    doInit()
    while true do
        -- Flush input
        updateRedstoneInput()
        -- Update status
        if(ab_station_time>0) then 
        ab_station_time=ab_station_time+1
        end
        if(ba_station_time>0) then
        ba_station_time=ba_statiom_time+1
        end
        if(mid_time>0) then 
        mid_time=mid_time+1
        end
        if(ab_exit_time>0) then
        ab_exit_time=ab_exit_time+1
        if(ab_exit_time>10) then -- Exit will reset in 10 loops (5seconds)
        ab_exit_time=0 
        end
        end
        if(ba_exit_time>0) then
        ba_exit_time=ba_exit_time+1
        if(ba_exit_time>10) then -- Exit will reset in 10 loops (5seconds)
        ba_exit_time=0 
        end
        end
        

        -- Judge Incoming bus.
        if(ab_st>0) then -- New incoming bus from A to B
            if(ab_sr>0) then -- This bus want to stop
                if(ab_station_time==0) then -- If AB Station is free
                    ab_ko=15 -- enable to allow incoming
                    ab_ks=0 -- disable to let it stop
                    ab_m=0 -- disable to allow incoming to station
                    ab_station_time=1 -- Start Time Counter
                else -- AB Station is not free
                    -- This train should wait outside the station
                end
            else -- This bus want to pass by
                if(mid_time==0) then -- Mid is free
                    ab_ko=15 -- enable to allow incoming
                    ab_m=15 -- enable motor to let it pass.
                    mid_ka=15 -- enable switch from A
                    mid_kb=0 -- disable switch to B
                    mid_direction="ab"
                    mid_time=1 -- Start time counter
                else -- Mid is busy
                    -- This train should wait outside the station
                end
            end
        end

        if(ba_st>0) then -- New incoming bus from B to A
            if(ba_sr>0) then -- This bus want to stop
                if(ba_station_time==0) then -- If BA Station is free
                    ba_ko=15 -- enable to allow incoming
                    ba_ks=0 -- disable to let it stop
                    ba_m=0 -- disable to allow incoming to station
                    ba_station_time=1 -- Start Time Counter
                else -- BA Station is not free
                    -- This train should wait outside the station
                end
            else -- This bus want to pass by
                if(mid_time==0) then -- Mid is free
                    ba_ko=15 -- enable to allow incoming
                    ba_m=15 -- enable motor to let it pass.
                    mid_ka=0
                    mid_kb=15
                    mid_direction="ba"
                    mid_time=1
                else -- Mid is busy
                    -- This train should wait outside the station
                end
           	end
        end
        
        if(ab_lout>0 and ab_exit_time==0) then -- AB next free
        -- Judge which train should pass.
        if(ab_station_time>16 and (mid_time>0 and mid_direction=="ab") ) then -- Two Trains
        if(ab_station_time>mid_time) then -- StationTrain wait longer.
        ab_station_time=0 -- Stop counter
        ab_ks=15 -- enable swith to let it go
        ab_exit_time=1
        else -- MidTrain wait longer
        mid_time=0 -- Stop Counter
        mid_kb=15
        ab_exit_time=1
        end
        elseif(ab_station_time>16) then --Only Station Train
        ab_station_time=0
        ab_ks=15
        ab_exit_time=1
        elseif(mid_time>0 and mid_direction=="ab") then -- Only Mid Train
        mid_time=0
        mid_kb=15
        ab_exit_time=1
        end -- No train
       
        end -- End of AB judge
        
        if(ba_lout>0 and ba_exit_time==0) then -- BA next free
        -- Judge which train should pass.
        if(ba_station_time>16 and (mid_time>0 and mid_direction=="ba") ) then -- Two Trains
        if(ba_station_time>mid_time) then -- StationTrain wait longer.
        ba_station_time=0 -- Stop counter
        ba_ks=15 -- enable swith to let it go
        ba_exit_time=1
        else -- MidTrain wait longer
        mid_time=0 -- Stop Counter
        mid_ka=15
        ba_exit_time=1
        end
        elseif(ba_station_time>16) then --Only Station Train
        ba_station_time=0
        ba_ks=15
        ba_exit_time=1
        elseif(mid_time>0 and mid_direction=="ba") then -- Only Mid Train
        mid_time=0
        mid_ka=15
        ba_exit_time=1
        end -- No train
        end

        -- Set output
        updateRedstoneOutput()

        -- Sleep for next loop
        os.sleep(0.5)
    end
end