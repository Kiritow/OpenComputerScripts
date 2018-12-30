-- Print Screen : Save screen to file
-- Author: Kiritow

require("libevent")
local shell=require("shell")
local filesystem=require("filesystem")
local component=require('component')

local args,options=shell.parse(...)

if(#args<1) then
    print("Usage: prtsc <start|stop>")
elseif(args[1]=="start") then
    if(filesystem.exists('/tmp/.prtsc.evid')) then
        print("PrtSc service already started.")
    else
        local f=io.open("/tmp/.prtsc.evid","w")
        if(not f) then
            print("Failed to open record file.")
        else
            local evid=AddEventListener("key_down",function(e)
                if(e.code==183) then
                    local gpu=component.list('gpu')()
                    if(gpu) then
                        gpu=component.proxy(gpu)
                        local name=os.tmpname()
                        local p=io.open(name,"w")
                        if(p) then
                            local w,h=gpu.getResolution()
                            for i=1,h do
                                for j=1,w do
                                    p:write((gpu.get(j,i)))
                                end
                                p:write('\n')
                            end
                            print("[PrtSc] Screen saved to " .. name)
                            p:close()
                        else
                            print("[PrtSc] Unable to open file: " .. name)
                        end
                    end
                end
            end)
            f:write(evid)
            f:close()
            print("PrtSc service started.")
        end
    end
elseif(args[1]=="stop") then
    if(not filesystem.exists('/tmp/.prtsc.evid')) then
        print("PrtSc service not started.")
    else
        local f=io.open("/tmp/.prtsc.evid","r")
        if(not f) then
            print("Failed to open record file.")
        else
            local evid=f:read("n")
            f:close()
            RemoveEventListener(evid)
            filesystem.remove("/tmp/.prtsc.evid")
            print("PrtSc service stopped.")
        end
    end
else
    print("Unknown command: " .. args[1])
end