drone_version="Drone v3.3c"
drone=component.proxy(component.list("drone")())
modem=component.proxy(component.list("modem")())
drone.setStatusText(drone_version .. '\n' .. modem.address)
modem.open(98)
H={["_anything"]={}}
T={}
W={}
local coC,coT,coY,coR,upt,tbI,tbR=coroutine.create,coroutine.running,coroutine.yield,coroutine.resume,computer.uptime(),table.insert,table.remove
handle_event=function(e)
    if(H[e[1]]) then 
        for i,tb in pairs(H[e[1]]) do 
            coR(tb.co,i,e) 
        end
    end
    for i,tb in pairs(H["_anything"]) do 
        coR(tb.co,i,e)
    end
end
sleep=function(sec)
    tbI(W,{id=0,tm=upt()+sec,co=coT()})
    tbR(W,coY())
end
cancel=function(id,wid)
    if(wid) then 
        tbR(W,wid) 
    else 
        for i,t in ipairs(W) do 
            if(t.id==id) then 
                tbR(W,i) 
                break 
            end 
        end
    end
    if(T[id]) then 
        T[id]=nil 
        return true
    else 
        return false 
    end
end
timer=function(sec,fn,times)
    tbI(T,{cb=fn,intv=sec,times=times})
    local id=#T
    tbI(W,{tm=upt()+sec,id=id,co=coC(function(wid)
        while true do 
            pcall(fn)
            local tb=T[id]
            if(tb.times<0 or tb.times>1) then 
                tb.times,tb.tm=tb.times-1,upt()+tb.intv
                wid=coY()
            else
                cancel(id,wid)
                return
            end
        end
    end)})
    return id
end
ignore=function(name,id)
    if(H[name][id]) then 
        H[name][id]=nil 
        return true
    else 
        return false 
    end
end
listen=function(name,cb)
    if(H[name]==nil) then 
        H[name]={}
    end
    tbI(H[name],{co=coC(function(i,e)
        while true do
            local ok,res=pcall(cb,e)
            if(ok and res~=nil and not res) then
                ignore(name,i)
                return
            end
            i,e=coY()
        end
    end)})
    return #H[name]
end
wait=function(sec,name)
    if(name==nil and type(sec)=="string") then name=sec sec=nil end
    sec=sec and upt()+sec or math.huge
    local this=coT()
    tbI(W,{id=0,tm=sec,co=this})
    name=name or "_anything"
    local id=listen(name,function(e) 
        coR(this,-1,e)
        return false
    end)
    local wid,e=coY()
    ignore(name,id)
    if(wid==-1) then
        for i,t in ipairs(W) do 
            if(t.co==this) then 
                tbR(W,i)
                break
            end
        end
        return e
    else
        tbR(W,wid)
        return nil
    end
end
listen("modem_message",function(e)
    if(e[6] and e[6]=='execute_command' and e[7]) then 
        local f,err=load(e[7])
        if(f) then
            local ok,err=pcall(function()
                modem.send(e[3],99,f())
            end)
            if(not ok) then
                modem.send(e[3],99,"CallError: " .. err)
            end
        else
            modem.send(e[3],99,"SyntaxError: " .. err)
        end
    end
end)
while true do
    local max_wait,max_id=math.huge,0
    for i,v in ipairs(W) do
        if(v.tm<max_wait) then 
            max_wait,max_id=v.tm,i
        end
    end
    local e
    if(max_wait==math.huge) then
        e=table.pack(computer.pullSignal())
    else
        e=table.pack(computer.pullSignal(max_wait-upt()))
    end
    if(e[1]==nil) then
        coR(W[max_id].co,max_id)
    else
        handle_event(e)
    end
end