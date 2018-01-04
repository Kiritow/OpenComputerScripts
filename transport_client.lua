local component=require("component")
local event=require("event")
require("util")

--- Auto Configure
local digital_controller = proxy("digital_controller_box")
local digital_receiver = proxy("digital_receiver_box")
local transposer = proxy("transposer")
local routing_track = proxy("routing_track")

--- Manually Configure
local route_in_ab = proxy("routing_switch","6")
local route_in_ba = proxy("routing_switch","a")
local route_out = proxy("routing_switch","1")

-- Value: 1 Green 2 Blinking Yello 3 Yello 4 Blinking Red 5 Red
local green=1
local byello=2
local yello=3
local bred=4
local red=5

local function setSignal(name,value)
    digital_controller.setAspect(name,value)
end

local function checkDevice()
    local function doCheckDevice(device)
        if(device==nil) then 
            error("Some device is nil. Please double check your configure.")
        end
    end

    doCheckDevice(digital_controller)
    doCheckDevice(digital_receiver)
    doCheckDevice(transposer)
    doCheckDevice(routing_track)
    doCheckDevice(route_in_ab)
    doCheckDevice(route_in_ba)
    doCheckDevice(route_out)

    local t=digital_controller.getSignalNames()

    local function checkSigName(name)
        local found=false
        for k,v in pairs(t) do 
            if(v==name) then
                return true
            end
        end
        error("CheckSigName: Failed to check signal: " .. name)
    end

    checkSigName("Cart_Ctrl")
    checkSigName("Lamp")
    checkSigName("Box_Ctrl")

    t=digital_receiver.getSignalNames()
    checkSigName("Cart_Ready")

    print("Check device pass.")
end

local function resetDevice()
    digital_controller.setEveryAspect(red)
    setSignal("Lamp",green)
    
    route_in_ab.setRoutingTable({})
    route_in_ba.setRoutingTable({})
    route_out.setRoutingTable({})

    print("Device reset done.")
end

local function main()
    checkDevice()
    resetDevice()

    while true do
        print("Please put your things in the box. Then press ENTER.")
        local e=event.pull(e)
    end
end

main()