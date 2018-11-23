drone=component.proxy(component.list("drone")())
modem=component.proxy(component.list("modem")())
drone_version="Drone v3.1"
drone.setStatusText(drone_version .. '\n' .. modem.address)
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
            local ok,result=pcall(function()
                callback(raw_event)
            end)
            if(ok and result) then break end
        end
    end
end
sleep=function(sec)
    local current=computer.uptime()
    local deadline=current + sec
    while true do
        local raw_event=table.pack(computer.pullSignal(deadline-current))
        if(raw_event[1]==nil) then break
        else handle_event(raw_event) end
        current=computer.uptime()
        if(current<dealine) then break end
    end
end

while true do
    handle_event(table.pack(computer.pullSignal()))
end