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
local ab_in_OutsideRoute,ab_in_EnterSensor,ab_in_ExitSensor
local ba_in_OutsideRoute,ba_in_EnterSensor,ba_in_ExitSensor
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
]]
local trainnet=proxy("tunnel")

-- Internal Schedule Status (Notice: Program must start without any trains in station)
local ab_station_free=true
local ba_station_free=true
local mid_free=true
local ab_next_free=true
local ba_next_free=true

-- Internal Functions
local function doInit()
    -- TODO
    event.listen("redstone_change")
    event.listen("modem_message")

    -- Flash output to zero.
    updateRedstoneOutput()
end

-- Main Program
local function main()
    doInit()
end