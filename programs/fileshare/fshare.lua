local component=require("component")
local shell=require("shell")
local uuid=require('uuid')
local filesystem=require('filesystem')
require("libevent")

print("File Share Server")
print("Author: Github/Kiritow")

local args,opts=shell.parse(...)

if((not opts["s"] and #args<1)) then
    print([==[Usage:
    fshare <Directory> [<Port>] [-dv]
    fshare -s [<Port>]
Options:
    -d Run fileshare server in background.
    -v Verbose. With this option, FileShare will output logs even running in background.
    -s Stop background fileshare server.
Notes:
    FileShare shares a directory on a specific port. By default, the port is 21.
]==])
    return
end

local modem=component.list("modem")()
if(not modem) then
    print("[Error] This program requires modem to work.")
    return
else
    modem=component.proxy(modem)
end

if(opts["s"]) then
    local port=21
    if(#args>0) then 
        port=tonumber(args[1])
    end
    if(not modem.isOpen(port)) then
        print("[Error] Service is not running on port " .. port)
        return
    end
    print("[Pending] Waiting for fileshare server response...")
    PushEvent("fss_stop",port)
    local e=WaitEvent(5,"fss_stopped")
    if(e~=nil) then
        print("[Done] Service stopped.")
    else
        print("[Error] fileshare server not response in 5 seconds.")
    end
    return
end

-- Server Program
local dir=args[1]
local port=21
if(#args>1) then 
    port=tonumber(args[2])
end

if(not modem.open(port)) then 
    print("[Error] Failed to open port "  .. port)
    return 
end

local function fss_server_main(xprint,to_wait)
    while true do
        local e=WaitMultipleEvent(table.unpack(to_wait))
        if(e.event=="interrupted") then
            xprint("Interrupted by user.")
            break
        elseif(e.event=="modem_message" and e.port==port and e.data[1]=="fs_req") then
            local filename=e.data[2]
            local realpath=filesystem.concat(dir,filename)
            xprint("Requesting: " .. realpath)
            local f=io.open(realpath,"rb")
            if(not f) then
                xprint("Not found: " .. realpath)
                modem.send(e.sender,22,"fs_ans_err")
            else
                local content=f:read("*a")
                f:close()
                modem.send(e.sender,22,"fs_ans_ok",content)
                xprint("Sent: " .. realpath)
            end
        elseif(e.event=="fss_stop" and e.data[1]==port) then
            xprint("Stopped by event.")
            modem.close(port)
            PushEvent("fss_stopped")
            break
        end
    end
end

if(opts["d"]) then
    local thisid=uuid.next()
    AddEventListener(thisid,function()
        fss_server_main(function() end,table.pack("modem_message","fss_stop"))
    end)
    PushEvent(thisid)
    print("[Done] FileShare Server started.")
else -- Run in foreground
    fss_server_main()
    print("[Stopped] File Share Server stopped.")
end
