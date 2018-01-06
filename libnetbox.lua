local component = require("component")
local event = require("event")
require("util")
require("libevent")

local netbox_router_port = 9999
local netbox_client_port = 9998

--- Auto Configure
local modem=proxy("modem")
local tunnel=proxy("tunnel")
local is_router=false

-- APIs

function SendData(target_address,port,...)
    if(not is_router) then
        modem.broadcast(netbox_router_port,"NetBox","Direct",target_address,port,...)
    end
end

function BroadcastData(port,...)
    if(not is_router) then
        modem.broadcast(netbox_router_port,"NetBox","Broadcast",port,...)
    end
end

function routerMain()
    modem.open(netbox_router_port)

    local bus=CreateEventBus()
    EventBusListen(bus,"modem_message")
    while true do 
        local e=GetNextEvent(bus,-1)
        if(e.receiverAddress==tunnel.address) then
            if(e.data[1]=="NetBoxAir") then
                if(e.data[2]=="Direct") then
                    print("Debug: Sending from " .. e.data[3] .. " to " .. e.data[4] .. " at port " .. netbox_client_port)
                    modem.send(e.data[4],netbox_client_port,"NetBox",e.data[3],table.unpack(e.data,5))
                elseif(e.data[2]=="Broadcast") then
                    print("Debug: Broadcasting at port " .. netbox_client_port .. " from " .. e.data[3])
                    modem.broadcast(netbox_client_port,"NetBox",e.data[3],table.unpack(e.data,4))
                end
            end
        elseif(e.receiverAddress==modem.address) then
            if(e.port==netbox_router_port and e.data[1]=="NetBox") then
                if(e.data[2]=="Direct") then
                    print("Debug: Tunnel Sending from " .. e.senderAddress .. " to " .. e.data[3])
                    tunnel.send("NetBoxAir","Direct",e.senderAddress,e.data[3],table.unpack(e.data,4))
                elseif(e.data[2]=="Broadcast") then
                    print("Debug: Tunnel Broadcast from " .. e.senderAddress .. " at port " .. e.port)
                    tunnel.send("NetBoxAir","Broadcast",e.senderAddress,e.data[3],table.unpack(e.data,4))
                end
            end
        end
    end
end

function clientServiceStart(redirect)
    modem.open(netbox_client_port)
    AddEventListener("modem_message",function(ev)
        if(ev.data[1]=="NetBox") then
            event.push("net_message",ev.receiverAddress,ev.data[2],ev.data[3],table.unpack(ev.data,4))
        end
    end)
end
