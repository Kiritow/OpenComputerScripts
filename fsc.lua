print("File Share Client")
print("Author: Github/Kiritow")

local component=require("component")
local shell=require("shell")
require("libevent")

local args,opts=shell.parse(...)
local argc=#args

local function cmd(cmdstr,infostr)
    local old=component.gpu.setForeground(0xFFFF00)
    print(cmdstr)
    component.gpu.setForeground(0x0000FF)
    print(infostr)
    component.gpu.setForeground(old)
end
local function err(info)
    local old=component.gpu.setForeground(0xFF0000)
    print(infostr)
    component.gpu.setForeground(old)
end

if(argc<3) then
    print("Usage:")
    cmd("fsc <RemoteFilename> <LocalFilename> <ServerAddr> [<Port>]",
    "Download file from server. Default port is 21.")
    return 
end

local filename=args[1]
local localfile=args[2]
local server=args[3]
local port=21
if(argc>3) then
    port=tonumber(args[4])
end

local modem=component.modem
if(modem==nil) then
    err("This program need a modem card to run.")
    return 
end

local bus=CreateEventBus()
bus:listen("interrupted")
bus:listen("modem_message")

if(not modem.open(22)) then
    err("Failed to open data receive port.")
    bus:close()
    return 
end

print("Connecting to " .. server .. " at port " .. port)
print("Press Ctrl+C will stop this process")
modem.send(server,port,"fs_req",filename)

local e=bus:next()

if(e.event=="modem_message") then
    if(e.data[1]=="fs_ans_err") then 
        err("Server encounter errors will process the request.")
    elseif(e.data[1]=="fs_ans_ok") then 
        print("Writing data to " .. localfile)
        local f=io.open(localfile,"wb")
        f:write(e.data[2])
        f:close()
    end
elseif(e.event=="interrupted") then
    print("Transmission cancelled.")
else
    print("Event: ",e.event)
end

bus:close()
modem.close(22)
