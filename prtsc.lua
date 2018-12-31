-- Print Screen : Save screen to file
-- Author: Kiritow

require("libevent")
local shell=require("shell")
local filesystem=require("filesystem")
local component=require('component')

local args,options=shell.parse(...)

local dprint
if(options["q"]) then
    dprint=function(...) end
else
    dprint=print
end

if(#args<1) then
    print([==[Usage: prtsc <start|stop> [-q]
Options: 
    -q: Don't print anything while PrtSc is pressed.]==])
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
                        local tmp={}
                        local w,h=gpu.getResolution()
                        for i=1,h do
                            for j=1,w do
                                table.insert(tmp,(gpu.get(j,i)))
                            end
                            table.insert(tmp,'\n')
                        end
                        tmp=table.concat(tmp,"")
                        local name=os.tmpname()
                        local p=io.open(name,"w")
                        if(p) then
                            p:write(tmp)
                            p:close()
                            dprint("[PrtSc] Screen saved to " .. name)
                            local dbg=component.list("debug")()
                            if(dbg) then
                                dbg=component.proxy(dbg)
                                dbg.sendToClipboard(e.playerName,tmp)
                                dprint("[PrtSc] Screen saved to clipboard.")
                            end
                        else
                            dprint("[PrtSc] Unable to open file: " .. name)
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