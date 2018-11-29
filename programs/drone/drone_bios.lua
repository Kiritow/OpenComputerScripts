drone_version="Drone v3.3b"
drone=component.proxy(component.list("drone")())
modem=component.proxy(component.list("modem")())
drone.setStatusText(drone_version .. '\n' .. modem.address)
modem.open(98)
handlers={}
timers={}
wake_list={}
handlers["_anything"]={}
handle_event=function(e)
    if(handlers[e[1]]) then 
        for i,tb in pairs(handlers[e[1]]) do 
            coroutine.resume(tb.co,i,e) 
        end
    end
    for i,tb in pairs(handlers["_anything"]) do 
        coroutine.resume(tb.co,i,e)
    end
end
sleep=function(sec)
    table.insert(wake_list,{id=0,tm=computer.uptime()+sec,co=coroutine.running()})
    table.remove(wake_list,coroutine.yield())
end
cancel=function(id,wid)
    if(wid) then 
        table.remove(wake_list,wid) 
    else 
        for i,t in ipairs(wake_list) do 
            if(t.id==id) then 
                table.remove(wake_list,i) 
                break 
            end 
        end
    end
    if(timers[id]) then 
        timers[id]=nil 
        return true
    else 
        return false 
    end
end
timer=function(sec,fn,times)
    table.insert(timers,{cb=fn,intv=sec,times=times})
    local id=#timers
    table.insert(wake_list,{tm=computer.uptime()+sec,id=id,co=coroutine.create(function(wid)
        while true do 
            pcall(fn)
            local tb=timers[id]
            if(tb.times<0 or tb.times>1) then 
                tb.times,tb.tm=tb.times-1,computer.uptime()+tb.intv
                wid=coroutine.yield()
            else
                cancel(id,wid)
                return
            end
        end
    end)})
    return id
end
ignore=function(name,id)
    if(handlers[name][id]) then 
        handlers[name][id]=nil 
        return true
    else 
        return false 
    end
end
listen=function(name,cb)
    if(handlers[name]==nil) then 
        handlers[name]={}
    end
    table.insert(handlers[name],{co=coroutine.create(function(i,e)
        while true do
            local ok,res=pcall(cb,e)
            if(ok and res~=nil and not res) then
                ignore(name,i)
                return
            end
            i,e=coroutine.yield()
        end
    end)})
    return #handlers[name]
end
wait=function(sec,name)
    if(name==nil and type(sec)=="string") then name=sec sec=nil end
    sec=sec and computer.uptime()+sec or math.huge
    local this=coroutine.running()
    table.insert(wake_list,{id=0,tm=sec,co=this})
    name=name or "_anything"
    local id=listen(name,function(e) 
        coroutine.resume(this,-1,e)
        return false
    end)
    local wid,e=coroutine.yield()
    ignore(name,id)
    if(wid==-1) then
        for i,t in ipairs(wake_list) do 
            if(t.co==this) then 
                table.remove(wake_list,i)
                break
            end
        end
        return e
    else
        table.remove(wake_list,wid)
        return nil
    end
end
listen("modem_message",function(e)
    local snd=e[3]
    local tag=e[6]
    local cmd=e[7]
    if(tag and tag=='execute_command' and cmd) then 
        local f,err=load(cmd)
        if(f) then
            local ok,err=pcall(f)
            if(not ok) then 
                modem.send(snd,99,"CallError: " .. res)
            else
                modem.send(snd,99,res)
            end
        else
            modem.send(snd,99,"SyntaxError: " .. err)
        end
    end
end)
while true do
    local max_wait,max_id=math.huge,0
    for i,v in ipairs(wake_list) do
        if(v.tm<max_wait) then 
            max_wait,max_id=v.tm,i
        end
    end
    local e
    if(max_wait==math.huge) then
        e=table.pack(computer.pullSignal())
    else
        e=table.pack(computer.pullSignal(max_wait-computer.uptime()))
    end
    if(e[1]==nil) then
        coroutine.resume(wake_list[max_id].co,max_id)
    else
        handle_event(e)
    end
end