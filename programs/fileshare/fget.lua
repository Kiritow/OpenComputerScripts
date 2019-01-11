local component=require("component")
local shell=require("shell")
require("libevent")

print("File Share Client")
print("Author: Github/Kiritow")

local args,opts=shell.parse(...)

if(#args<2) then
    print([==[Usage:
    fsc <RemoteFilename> <LocalFilename> [<ServerAddr>] [-b] [--port]
Options:
    --port Set which port to connect to server. By default it is 21.
    -b Use broadcast mode.
Notes:
    fget get a file from FileShare server.
]==])
    return
end

local filename=args[1]
local localfile=args[2]
local server=args[3]
local port=21
if(opts["port"]) then
    port=tonumber(opts["port"])
end

local modem=component.list("modem")()
if(not modem) then
    print("[Error] This program requires a modem to run.")
    return 
else
    modem=component.proxy(modem)
end

if(not modem.open(22)) then
    print("[Error] Failed to open data receive port.")
    return
end

if(opts["b"]) then
    print("Broadcasting at port " .. port)
    modem.broadcast(port,"fs_req",filename)
else
    print("Connecting to " .. server .. " at port " .. port)
    modem.send(server,port,"fs_req",filename)
end
print("Press Ctrl+C will stop this process")
while true do
    local e=WaitMultipleEvent("modem_message","interrupted")
    if(e.event=="modem_message" and e.port==22) then
        if(e.data[1]=="fs_ans_err") then
            print("[Error] Remote server reported failure on this request.")
        elseif(e.data[1]=="fs_ans_ok") then
            print("[Working] Writing data to " .. localfile)
            local f=io.open(localfile,"wb")
            if(not f) then
                print("[Error] Failed to open file: " .. localfile)
            else
                local ret,err=f:write(e.data[2])
                if(not ret) then
                    print("[Error] Failed while writing file: " .. err)
                else
                    print("[Done] Data written to file: " .. localfile)
                end
                f:close()
            end
        end
        break
    elseif(e.event=="interrupted") then
        print("[Error] Interrupted by user.")
        break
    end
end
modem.close(22)
