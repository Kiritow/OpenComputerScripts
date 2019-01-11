-- LibMCNet
local component=require('component')
local core=require('mcnet_core')

local mcnetd_version=1
local default_ttl=5

local function NetSendEx(modem,dest,port,...)
    local t={}
    t.ver=mcnetd_version
    t.ttl=default_ttl
    t.src=modem.address
    t.dest=dest
    t.port=port
    t.data=table.pack(...)
    core.send(t)
end

-- NetSend(component.modem,"dest-uuid",80,"GET / Hello.World")
-- NetSend("dest-uuid",80,"GET / Hello.World")
local function NetSend(a,b,c,...)
    if(not a or type(a)=="table") then
        NetSendEx(a or component.modem,b,c,...)
    else
        NetSendEx(component.modem,a,b,c,...)
    end
end

local function NetBroadcast(port,...)
    local t={}
    t.ver=mcnetd_version
    t.ttl=default_ttl
    t.src=component.modem.address
    t.port=port
    t.data=table.pack(...)
    core.broadcast(t)
end

local function SetTTL(ttl)
    default_ttl=ttl
end

return {
    send=NetSend,
    broadcast=NetBroadcast,
    setttl=SetTTL
}