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

local internal_port={}

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

function OpenPort(port)
    checknumber(port)
    if(internal_port[port]~=nil) then
        return false,"Port has been opened."
    else
        internal_port[port]=true
    end
end

function ClosePort(port)
    checknumber(port)
    if(internal_port[port]~=nil) then
        internal_port[port]=nil
        return true
    else
        return false,"Port has been closed."
    end
end

function routerMain()
    if(modem.open(netbox_router_port)==false) then
        error("Failed to open router port on real netcard.")
    end

    print("Router Started.")

    local bus=CreateEventBus()
    bus:listen("modem_message")
    bus:listen("interrupted")
    while true do 
        local e=bus:next(-1)

        if(e.event=="interrupted") then
            break
        end

        if(e.receiverAddress==tunnel.address) then
            if(e.data[1]=="NetBoxAir") then
                if(e.data[2]=="Direct") then
                    modem.send(e.data[4],netbox_client_port,"NetBox",e.data[3],table.unpack(e.data,5))
                elseif(e.data[2]=="Broadcast") then
                    modem.broadcast(netbox_client_port,"NetBox",e.data[3],table.unpack(e.data,4))
                end
            end
        elseif(e.receiverAddress==modem.address) then
            if(e.port==netbox_router_port) then
                if(e.data[1]=="NetBox") then
                    if(e.data[2]=="Direct") then
                        tunnel.send("NetBoxAir","Direct",e.senderAddress,e.data[3],table.unpack(e.data,4))
                    elseif(e.data[2]=="Broadcast") then
                        tunnel.send("NetBoxAir","Broadcast",e.senderAddress,e.data[3],table.unpack(e.data,4))
                    end
                end
            end
        end
    end

    bus:reset()

    modem.close(netbox_router_port)

    print("Router Stopped.")
end

function clientServiceStart(redirect)
    if(modem.open(netbox_client_port)==false) then
        error("Failed to start client service. Real modem port can not be opened.")
    end

    AddEventListener("modem_message",function(ev)
        if(ev.data[1]=="NetBox" and internal_port[ev.data[3]]~=nil ) then
            event.push("net_message",ev.receiverAddress,ev.data[2],ev.data[3],table.unpack(ev.data,4))
        end
    end)
end
