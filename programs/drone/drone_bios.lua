drone=component.proxy(component.list("drone")())
modem=component.proxy(component.list("modem")())
drone_version="Drone v3.2"
drone.setStatusText(drone_version .. '\n' .. modem.address)
modem.open(98)
handlers={}
timers={}
wake_list={}
handlers["_anything"]={}
handle_event=function(e)
    if(handlers[e[1]]) then for i,tb in pairs(handlers[e[1]]) do coroutine.resume(tb.co,i,e) end end
    for i,tb in pairs(handlers["_anything"]) do coroutine.resume(tb.co,i,e) end
end
sleep=function(sec)
    local this,flag=coroutine.running()
    table.insert(wake_list,{id=0,tm=computer.uptime()+sec,co=this})
    local this_id=coroutine.yield()
    table.remove(wake_list,this_id)
end
cancel=function(id)
    if(timers[id]) then for i,t in ipairs(wake_list) do if(t.id==id) then table.remove(wake_list,i) break end end timers[id]=nil return true 
    else return false end
end
timer=function(sec,fn,times)
    local next=computer.uptime()+sec
    local id=table.insert(timers,{cb=fn,intv=sec,times=times})
    table.insert(wake_list,{tm=next,id=id,co=coroutine.create(function(this_id)
        while true do 
            pcall(fn) 
            local this_tb=timers[this.id]
            if(this_tb.times>0) then this_tb.times=this_tb.times-1 
                if(this_tb.times<1) then timer[wake_list[this_id].id]=nil table.remove(wake_list,this_id) return
                else this.tm=computer.uptime()+this_tb.intv this_id=coroutine.yield() end
            end
        end
    end)})
    return id
end
ignore=function(name,id)
    handlers[name][id]=nil
end
listen=function(name,cb)
    if(handlers[name]==nil) then handlers[name]={} end
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
    if(sec==nil and name==nil) then sec=-1 
    elseif(sec==nil and name~=nil) then sec=-1
    elseif(sec~=nil and name==nil) then if(type(sec)=="string") then name=sec sec=-1 end end
    local this,flag=coroutine.running()
    if(sec>=0) then
        table.insert(wake_list,{id=0,tm=computer.uptime()+sec,co=this})
    else
        table.insert(wake_list,{id=0,tm=math.huge,co=this})
    end
    local id
    if(name~=nil) then
        id=listen(name,function(e) if(e[1]==name) then coroutine.resume(this,-1,e) return false end end)
    else
        id=listen("_anything",function(e) coroutine.resume(this,-1,e) return false end)
    end
    local this_id,e=coroutine.yield()
    if(this_id==-1) then
        for idx,t in ipairs(wake_list) do if(t.co==this) then table.remove(wake_list,idx) end end
        return e
    else
        ignore(id)
        table.remove(wake_list,this_id)
        return nil
    end
end
listen("modem_message",function(e)
    local snd=e[3]
    local tag=e[6]
    local cmd=e[7]
    if(tag~=nil and cmd~=nil and tag=='execute_command') then 
        local ok,err=pcall(function() 
            local f=load(cmd)
            local cmdok,cmdresult=pcall(f)
            if(not cmdok) then
                modem.send(snd,99,"Failed to execute: " .. cmdresult)
            else
                modem.send(snd,99,cmdresult)
            end
        end)
        if(not ok) then
            modem.send(snd,99,"Command Execute Failed: " .. err)
        end
    end
end)
while true do
    local max_wait,max_id=math.huge,0
    for i,v in ipairs(wake_list) do
        if(v.tm<max_wait) then max_wait,max_id=v.tm,i end
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