print("File Share Server")
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
if(argc<1) then
    print("Usage:")
    cmd("fss <Directory> [<Port>] [-d]",
    "Share a directory on specific port. Default port is 21. If with -d option, fss will run background.")
    cmd("fss -s [<Port>]",
    "Stop background fss on specific port.")
    return 
end
local op_stop=false
local op_daemon=false
for k in pairs(opts) do
    if(k=="s") then
        op_stop=true
    elseif(k=="d") then
        op_daemon=true
    end
end

if(op_stop) then
    local port=21
    if(argc>0) then 
        port=tonumber(args[1])
    end
    if(not component.modem.isOpen(port)) then
        err("Service is not running on port " .. port)
        return
    end
    local bus=CreateEventBus()
    local done=false
    bus:listen("fss_stopped")
    PushEvent("fss_stop")
    local e=bus:next()
    bus:close()
    print("Service stopped.")

    return
end

-- Server Program
local dir=args[1]
local port=21
if(argc>1) then 
    port=tonumber(args[2])
end

local bus=CreateEventBus()
bus:listen("modem_message")
bus:listen("fss_stop")
bus:listen("interrupted")

local modem=component.modem
if(not modem.open(port)) then 
    err("Failed to start service at port "  .. port)
    return 
end

print("File Share Server started successfully.")
local xprint=io.write

while true do 
    local e=bus:next()
    if(e.event=="modem_message" and e.port==port and e.data[1]=="fs_req") then
        local filename=e.data[2]
        local realfile=dir .. "/" .. filename
        xprint("Requesting file: ",realfile," ")
        local f=io.open(realfile,"rb")
        if(f==nil) then
            print("[Not Found]")
            modem.send(e.senderAddress,22,"fs_ans_err")
        else
            local content=f:read("*a")
            f:close()
            modem.send(e.senderAddress,22,"fs_ans_ok",content)
            print("[Sent]")
        end
    elseif(e.event=="fss_stop" or e.event=="interrupted") then
        break
    end
end

modem.close(port)
bus:close()
PushEvent("fss_stopped")

print("File Share Server stopped.")