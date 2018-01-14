require("libevent")
require("util")
local serialization=require("serialization")

--- Auto configured
local t=proxy("tunnel")
local wc=proxy("digital_detector")

--- Manunal configure
local report_name="SL-1-1"

local function main()
    if(type(t)=="nil") then
        error("Tunnel card not found.")
    end
    if(type(wc)=="nil") then
        error("Digital detector not found.")
    end

    local bus=CreateEventBus()
    bus:listen("minecart")
    bus:listen("interrupted")

    while true do 
        local e=bus:next()
        if(e.event=="interrupted") then
            break
        elseif(e.event=="minecart") then
            local tb={}
            tb.type=e.minecartType
            tb.dest=e.destination
            t.send("TrainReport",serialization.serialize(tb))
            print("Train:",e.minecartType,e.destination)
        end
    end

    bus:reset()
end

print("Train Report Watcher Started!")
print("Author: Kiritow")
print("StationName: ",report_name)
print("Press Ctrl+C to stop program.")
main()
print("Program stopped.")
