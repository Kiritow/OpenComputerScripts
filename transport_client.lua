local component=require("component")
require("libevent")
require("util")

--- Auto Configure
local digital_controller = proxy("digital_controller_box")
local digital_receiver = proxy("digital_receiver_box")
local out_ticket = proxy("routing_track")

--- Manually Configure
local load_detector = proxy("digital_detector","0")
local unload_detector = proxy("digital_detector","4")

local load_transposer = proxy("transposer","7")
local unload_transposer = proxy("transposer","6")

local route_ab_load = proxy("routing_switch","0c")
local route_ba_load = proxy("routing_switch","088")
local route_ab_unload = proxy("routing_switch","08c")
local route_ba_unload = proxy("routing_switch","c")


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
    print("Checking Devices...")

    local function doCheckDevice(device)
        if(device==nil) then 
            error("Some device is nil. Please double check your configure.")
        end
    end

    doCheckDevice(digital_controller)
    doCheckDevice(digital_receiver)
    doCheckDevice(out_ticket)
    
    doCheckDevice(load_detector)
    doCheckDevice(unload_detector)
    doCheckDevice(route_ab_load)
    doCheckDevice(route_ba_load)
    doCheckDevice(route_ab_unload)
    doCheckDevice(route_ba_unload)

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

    checkSigName("AInCtrl")
    checkSigName("BInCtrl")
    checkSigName("LoadCartCtrl")
    checkSigName("LoadBoxCtrl")
    checkSigName("UnloadCartCtrl")
    checkSigName("UnloadBoxCtrl")
    checkSigName("OutCtrl")

    t=digital_receiver.getSignalNames()
    checkSigName("LoadCartSig")
    checkSigName("UnloadCartSig")

    local function checkRoutingTable(device)
        if(device.getRoutingTableTitle()==false) then 
            error("CheckRoutingTable: Failed to check routing table. Please insert a routing table in it.")
        end
    end

    checkRoutingTable(route_ab_load)
    checkRoutingTable(route_ba_load)
    checkRoutingTable(route_ab_unload)
    checkRoutingTable(route_ba_unload)

    local function checkRoutingTicket(device)
        if(device.getDestination()==false) then 
            error("CheckRoutingTicket: Failed to check routing track. Please insert a golden ticket in it.")
        end
    end

    checkRoutingTicket(out_ticket)

    print("Check device pass.")
end

local function resetDevice()
    print("Reseting Devices...")
    
    digital_controller.setEveryAspect(red)
    
    route_ab_load.setRoutingTable({})
    route_ba_load.setRoutingTable({})
    route_ab_unload.setRoutingTable({})
    route_ba_unload.setRoutingTable({})

    print("Device reset done.")
end

local function main()
    checkDevice()
    resetDevice()
end

print("Transport System Client Started.")
print("Author: Kiritow")
main()
print("Transport System Client Stopped.")