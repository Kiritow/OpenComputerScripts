-- MCNet Core
local component=require('component')
local event=require('event')
local serialization=require('serialization')

local config={}
config.mcnetd_version=1
config.port=53
config.itvl=60
config.modem=component.list("modem")()
if(config.modem) then 
    config.modem=component.proxy(config.modem)
else
    config.modem={
        send=function() end,
        broadcast=function() end
    }
end

local dns_table={}

local function RBroadcast(t)
    config.modem.broadcast(config.port,serialization.serialize(t))
end

local function RSend(dest,t)
    config.modem.send(dest,config.port,serialization.serialize(t))
end

local function GSend(t)
    t.dest=dns_table[t.dest] or t.dest
    RBroadcast(t)
end

local function GBroadcast(t)
    RBroadcast(t)
end

local function GEventCallback(ename,receiver,sender,port,distance,dtb)
    if(config.modem.address==receiver and port==config.port and receiver~=sender) then
        local t=serialization.unserialize(dtb)
        if(type(t)=="table" and type(t.ver)=="number" and t.ver==config.mcnetd_version) then
            if(not t.flag) then
                if(not t.dest or t.dest==receiver) then
                    event.push("modem_message",receiver,t.src,t.port,0,table.unpack(t.data))
                elseif(t.ttl>1) then
                    t.ttl=t.ttl-1
                    GSend(t)
                end
            elseif(t.flag==0) then
                local t={}
                t.ttl=1
                t.ver=config.mcnetd_version
                t.flag=1
                t.data=dns_table
                RSend(sender,t)
            elseif(t.flag==1) then
                for k,v in pairs(t.data) do
                    if(not dns_table[k]) then
                        dns_table[k]=v
                    end
                end
            end
        end
    end
end

local function KflushDNS()
    local t={}
    t.ttl=1
    t.ver=config.mcnetd_version
    t.flag=0 -- DNS Sync request
    RBroadcast(t)
end

local function GTimer()
    KflushDNS()
end

return {
    send=GSend,
    broadcast=GBroadcast,

    internal={
        evcb=GEventCallback,
        tmcb=GTimer,
        config=config,
        dns=dns_table
    }
}