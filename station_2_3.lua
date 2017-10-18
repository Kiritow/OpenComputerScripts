--[[
Station 2/3 Schedule Program
]]

require("util")
local sides=require("sides")
local event=require("event")
--[[
Redstone Signals
Direction_IO_Description : number
]]
local ab_in_OutsideRoute,ab_in_OutsideSensor,ab_in_EnterSensor,ab_in_ExitSensor
local ba_in_OutsideRoute,ba_in_OutsideSensor,ba_in_EnterSensor,ba_in_ExitSensor
local mid_in_lamp

local ab_out_Outside,ab_out_Motor,ab_out_Stop=0,0,0
local ba_out_Outside,ba_out_Motor,ba_out_Stop=0,0,0
local mida_out_Stop,midb_out_Stop=0,0

-- Config your update functions here (Do not change function name)
local redin1=proxy("redstone","")
local redin2=proxy("redstone","")
local redout1=proxy("redstone","")
local redout2=proxy("redstone","")

local function updateRedstoneInput()

end

local function updateRedstoneOutput()

end

--[[
Network
Schedule program must connect to MC.TrainNet to send and recv train status.
Config your connect-card here
NOTICE: You must give different value to station_id (>=0)
]]
local trainnet=proxy("tunnel")
local station_id=0
local station_a_id=-1
local station_b_id=-1

-- Internal Schedule Status (Notice: Program must start without any trains in station)
local ab_station_free=true
local ba_station_free=true
local mid_free=true
local mid_direction="ab"
local ab_next_free=true
local ba_next_free=true
local ab_station_time=0
local ba_station_time=0
local ab_exit_time=0
local ba_exit_time=0

--[[
    Internal Functions
]]

local netpack_head=string.pack("iii",6,1,1)

local function doInit()
    -- TODO: You must change this function to fix your station
    event.listen("redstone_change",
        function(_event,_addr,_side,_old,_new)
            -- [NOTICE] Change information here!!
            -- Here: your must send an arrive message to last station
            
        end
    )
    event.listen("modem_message",
        function(_event,_recevier,_sender,_port,_distance,...)
            local apack={...}
            -- netpack_head FromStationID ToStationID Message(1: Leave 2: Arrive)
            if(apack[1]==netpack_head) then
                if(apack[3]==station_id) then -- Train will come to this station
                    -- Just do nothing (We don't worry about it)
                elseif(apack[2]==station_id) then -- Information about train left from this station
                    if(apack[4]==2) then -- Train arrives information
                        if(apack[3]==station_a_id) then -- Arrive at A
                            ba_next_free=true
                        elseif(apack[3]==station_b_id) then -- Arrive at B
                            ab_next_free=true
                        end
                    end -- We don't care about leave information
                end
            end
        end
    )

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
        if(ab_in_OutsideSensor>0) then -- New incoming bus from A to B
            if(ab_in_OutsideRoute>0) then -- This bus want to stop
                if(ab_station_free) then -- If AB Station is free
                    ab_station_free=false -- Mark station busy.
                    ab_out_Outside=15 -- enable to allow incoming
                    ab_out_Motor=0 -- disable to allow incoming to station
                    ab_station_time=1
                else -- AB Station is not free
                    -- This train should wait outside the station
                end
            else -- This bus want to pass by
                if(mid_free) then -- Mid is free can pass
                    mid_free=false -- Mark mid busy.
                    ab_out_Outside=15 -- enable to allow incoming
                    ab_out_Motor=15 -- enable motor to let it pass.
                    mid_direction="ab"
                else -- Mid is busy
                    -- This train should wait outside the station
                end
            end
        end

        if(ba_in_OutsideSensor>0) then -- New incoming bus from B to A
            if(ba_in_OutsideRoute>0) then -- This bus want to stop
                if(ba_station_free) then -- If BA Station is free
                    ba_station_free=false -- Mark station busy.
                    ba_out_Outside=15 -- enable to allow incoming
                    ba_out_Motor=0 -- disable to allow incoming to station
                    ba_station_time=1
                else -- BA Station is not free
                    -- This train should wait outside the station
                end
            else -- This bus want to pass by
                if(mid_free) then -- Mid is free can pass
                    mid_free=false -- Mark mid busy.
                    ba_out_Outside=15 -- enable to allow incoming
                    ba_out_Motor=15 -- enable motor to let it pass.
                    mid_direction="ba"
                else -- Mid is busy
                    -- This train should wait outside the station
                end
           	end
        end
        
        if(ab_next_free and ab_exit_time==0) then -- AB next free
        if(ab_station_time>16) then -- 8 seconds in station
        ab_out_Stop=15 -- enable stop to let it leave
        ab_exit_time=1 -- Start Count time
        elseif((not mid_free) and mid_direction=="ab") then -- Mid is busy and will leave with AB direction
        midb_out_Stop=15 --enable stop to let it leave
        ab_exit_time=1 -- Start Count time
        end
        end
        
        if(ba_next_free and ba_exit_time==0) then -- BA next free
        if(ba_station_time>16) then -- 8 seconds in station
        ba_out_Stop=15 -- enable stop to let it leave
        ba_exit_time=1 -- Start count time
        elseif((not mid_free) and mid_direction=="ba") then -- Mid is busy and will leave with BA direction
        mida_out_Stop=15 -- enable stop to let it leave
        ba_exit_time=1 -- Start count time
        end
	       end

        -- Set output
        updateRedstoneOutput()

        -- Sleep for next loop
        os.sleep(0.5)
    end
end