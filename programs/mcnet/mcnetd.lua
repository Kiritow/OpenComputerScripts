-- mcnet daemon
local component=require('component')
local event=require('event')
local core=require('mcnet_code')

local xprint=function(...)
    io.write("[mcnetd] ")
    print(...)
end

local modem=component.list("modem")()
if(not modem) then
    xprint("No modem card found. Exiting mcnetd...")
    return
else
    modem=component.proxy(modem)
    xprint("Found modem: " .. modem)
end

if(not modem.open(core.internal.config.port)) then
    xprint("Failed to open mcnetd port.")
    return
end

xprint("Starting mcnetd " .. core.mcnetd_version .. " on port " .. core.internal.config.port)
core.internal.config.modem=modem
local lid=event.listen("modem_message",core.internal.evcb)
local tid=event.timer(core.internal.config.itvl,core.internal.tmcb,math.huge)
core.internal.listenerid=lid
core.internal.timerid=tid
xprint("mcnetd started with listener id: " .. lid .. ", timer id: " .. tid)
