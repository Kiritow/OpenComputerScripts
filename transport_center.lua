local component=require("component")
require("libevent")
require("libnetbox")
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
        if(k>nextid) then nextid=k+1 end
    end
    idt[nextid]=true
    return nextid
end

local function main()
    checkDevice()
    clientServiceStart()

    OpenPort(10010)

    print("Center Started. Press Ctrl+C to stop.")

    while true do
        local e=WaitEvent()
        if(e~=nil) then
            if(e.event=="net_message" and e.data[1]=="TSCM") then
                if(e.data[2]=="req") then 
                    if(e.data[3]=="store") then
                        local id=getNextID()
                        SendData(e.senderAddress,10011,"TSCM","ack","pass",id)
                        print("NextID: ",id)
                    end
                end
            elseif(e.event=="interrupted") then 
                break
            end
        end
    end

    ClosePort(10010)
    clientServiceStop()
end

print("Transport System Center Started.")
print("Author: Kiritow")
main()
print("Transport System Center Stopped.")