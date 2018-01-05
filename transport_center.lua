local component=require("component")
require("libevent")
require("util")

--- Auto Configure
local network_card = proxy("modem")

local function checkDevice()
    print("Checking Devices...")

    local function doCheckDevice(device)
        if(device==nil) then 
            error("Some device is nil. Please double check your configure.")
        end
    end

    doCheckDevice(network_card)
    
    print("Device check pass.")
end

local idt={}

local function getNextID()
    local nextid=1
    for k,v in pairs(idt) do 
        if(v>nextid) then nextid=v+1 end
    end
    return nextid
end

local function main()
    checkDevice()

    network_card.open(10010)

    print("Center Started. Press Ctrl+C to stop.")

    while true do
        local e=WaitEvent()
        if(e~=nil) then
            if(e.event=="modem_message" and e.data[1]=="TSCM") then
                if(e.data[2]=="req") then 
                    if(e.data[3]=="store") then
                        local id=getNextID()
                        network_card.send(e.senderAddress,10011,"TSCM","ack","pass",id)
                        print("NextID: ",id)
                    end
                end
            elseif(e.event=="interrupted") then 
                break
            end
        end
    end

    network_card.close(10010)
end

print("Transport System Center Started.")
print("Author: Kiritow")
main()
print("Transport System Center Stopped.")