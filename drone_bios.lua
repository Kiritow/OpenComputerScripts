local drone=component.proxy(component.list("drone")())
local network=component.proxy(component.list("tunnel")())

while true do
    local evt,_,sender,port,dist,cmd=computer.pullSignal()
    if(evt=="modem_message") then
        local xok,xresult=pcall(function() 
            local ok,result=pcall(load(cmd))
            if(ok) then 
                network.send(result)
            else
                network.send("Command Execute Failed: " .. result)
            end
        end)
        if(not xok) then
            network.send("Internal Error: " .. xresult)
        end
    end
end

------------------------------------

drone=component.proxy(component.list("drone")())
drone.setStatusText("Drone v3.0")
modem=component.proxy(component.list("modem")())
modem.open(98)
handlers={}
handlers["modem_message"]={}
table.insert(handlers["modem_message"],function(event)
    local sender=event[3]
    local tag=event[6]
    local cmd=event[7]
    if(tag~=nil and cmd~=nil and tag=='execute_command') then 
        local ok,err=pcall(function() 
            local f=load(cmd)
            local cmdok,cmdresult=pcall(f)
            if(not cmdok) then
                modem.send(sender,99,"Failed to execute: " .. cmdresult)
            else
                modem.send(sender,99,cmdresult)
            end
        end)
        if(not ok) then
            modem.send(sender,99,"Command Execute Failed: " .. err)
        end
    end
end)
handle_event=function(raw_event)
    if(handlers[raw_event[1]]~=nil) then
        for idx,callback in ipairs(handlers[raw_event[1]]) do
            pcall(function()
                callback(raw_event)
            end)
        end
    end
end
sleep=function(sec)
    local deadline=computer.uptime() + sec
    while true do
        local raw_event=table.pack(computer.pullSignal(deadline-computer.uptime()))
        if(raw_event[1]==nil) then break
        else handle_event(raw_event)
        end
    end
end

while true do
    handle_event(table.pack(computer.pullSignal()))
end

-------------------------
--- sleep implementation for drone
-------------------------

sleep=function(sec)
    local deadline=computer.uptime() + sec
    while true do
        local raw_event=table.pack(computer.pullSignal(deadline-computer.uptime()))
        if(raw_event[1]==nil) then break
        else handle_event(raw_event)
        end
    end
end

------------------------------------
-- Wireless ADS Sender (Running on Computer)
------------------------------------

while true do
    component.modem.broadcast(101,"ads_tower","MainCity")
    os.sleep(1)
end