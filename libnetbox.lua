local component = require("component")
local event = require("event")
local serialization = require("serialization")
require("util")
require("libevent")
require("checkarg")

local function compress(t)
    checktable(t)
    return serialization.serialize(t)
end

local function decompress(x)
    checkstring(x)
    return serialization.unserialize(x)
end

local netbox_router_port = 9999
local netbox_client_port = 9998

local internal_port={}

--- Auto Configure
local modem=proxy("modem")
local tunnel=proxy("tunnel")
local is_router=false

-- Hardware Check

local function doHardwareCheck()
    if(modem==nil) then
        error("Libnetbox[Warning]: modem not avaliable.")
    end

    if(tunnel==nil) then
        is_router=false
    else
        is_router=true
    end
end

-- APIs

function SendData(target_address,port,...)
    if(not is_router) then
        local dt={}
        dt["target"]=target_address
        dt["method"]="Direct"
        dt["data"]=compress(table.pack(...))

        modem.broadcast(netbox_router_port,"NetBox",port,compress(dt))
    end
end

function BroadcastData(port,...)
    if(not is_router) then
        local dt={}
        dt["method"]="Broadcast"
        dt["data"]=compress(table.pack(...))

        modem.broadcast(netbox_router_port,"NetBox",port,compress(dt))
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
                local port=e.data[2]
                local tt=decompress(e.data[3])

                local dt={}
                dt.senderAddress=tt.senderAddress
                dt.data=tt.data

                if(tt.method=="Direct") then
                    modem.send(tt.target,netbox_client_port,"NetBox",port,compress(dt))
                elseif(tt.method=="Broadcast") then
                    modem.broadcast(netbox_client_port,"NetBox",port,compress(dt))
                end
            end
        elseif(e.receiverAddress==modem.address) then
            if(e.port==netbox_router_port and e.data[1]=="NetBox") then
                local port=e.data[2]
                local dt=decompress(e.data[3])

                local tt={}
                tt.data=dt.data
                tt.method=dt.method
                tt.senderAddress=e.senderAddress

                if(dt.method=="Direct") then
                    tt.target=dt.target
                    tunnel.send("NetBoxAir",port,compress(tt))
                elseif(dt.method=="Broadcast") then
                    tunnel.send("NetBoxAir",port,compress(tt))
                end
            end
        end
    end

    bus:reset()

    modem.close(netbox_router_port)

    print("Router Stopped.")
end

local _clientService_hand=-1

function NetBoxInit(redirect)
    if(modem.open(netbox_client_port)==false) then
        if(modem.isOpen(netbox_client_port)==false) then
            error("Failed to start client service. Real modem port can not be opened.")
        else
            print("libnetbox: Modem port has been opened. This may cause something wrong...")
        end
    end

    if(_clientService_hand<0) then
        _clientService_hand=AddEventListener("modem_message",function(ev)
            if(ev.data[1]=="NetBox" and internal_port[ev.data[2]]~=nil) then
                local dt=decompress(ev.data[3])
                event.push("net_message",ev.receiverAddress,dt.senderAddress,ev.data[2],table.unpack(decompress(dt.data)))
            end
        end)
    else
        print("libnetbox: Service has been started before. This may cause something wrong...")
    end
end

function NetBoxCleanUp()
    if(_clientService_hand>=0) then
         RemoveEventListener(_clientService_hand)
         _clientService_hand=-1
    end
    modem.close(netbox_client_port)
end

-- Do hardware check
doHardwareCheck()
