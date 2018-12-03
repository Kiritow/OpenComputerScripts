require("libevent")
local text=require('text')
local term=require('term')
local colors=require('colors')
local component=require('component')
local computer=require('computer')

local modem=component.modem

term.clear()
print('Drone Debug Console')
print('Initializing...')
modem.open(99)
print('Broadcasting initial commands...')
modem.broadcast(98,'drone=component.proxy(component.list("drone")())')
modem.broadcast(98,'modem=component.proxy(component.list("modem")())')
print('Done')

term.clear()
print('Drone Debug Console v1.4.4-beta')
print('Command Prompt (Ctrl+D to exit)')

local function SetResponse(msg)
    local a,b=term.getCursor()

    local w,h=term.gpu().getResolution()
    term.gpu().fill(1,h/2,w,h/2-3,' ')
    
    term.setCursor(1,h/2)
    print("Response")
    print(msg)

    term.setCursor(a,b)
end

local last_response=computer.uptime()

local listener=AddEventListener("modem_message",function(e) 
    if(e.data[1]~=nil and e.data[1]=='console_info') then
        last_response=computer.uptime()

        local a,b=term.getCursor()

        local w,h=term.gpu().getResolution()
        term.gpu().fill(1,h,w,1,' ')
        local text="device: " .. string.sub(e.senderAddress,1,8) .. " distance: " .. string.format("%.2f",e.distance) .. " offset: " .. string.format("%.2f",e.data[2]) .. " energy:"
        term.gpu().set(1,h,text)
        if(e.data[3]>3000) then
            local temp=term.gpu().setForeground(0x00FF00)
            term.gpu().set(string.len(text),h," " .. e.data[3])
            term.gpu().setForeground(temp)
        elseif(e.data[3]>1500) then
            local temp=term.gpu().setForeground(0xFFFF00)
            term.gpu().set(string.len(text),h," " .. e.data[3])
            term.gpu().setForeground(temp)
        else
            local temp=term.gpu().setForeground(0xFF0000)
            term.gpu().set(string.len(text),h," " .. e.data[3])
            term.gpu().setForeground(temp)
        end

        term.setCursor(a,b)
    elseif(e.data[1]~=nil and e.data[1]~='hide_msg') then
        SetResponse("[Remote] " .. e.data[1])
    end -- nil,'hide_msg' response are not rendered.
end)

local function add_ping_timer()
    return AddTimer(5,function()
        if(computer.uptime()-last_response>10) then 
            local a,b=term.getCursor()

            local w,h=term.gpu().getResolution()
            term.gpu().fill(1,h,w,1,' ')

            local temp=term.gpu().setForeground(0xFF0000)
            term.gpu().set(1,h,"No drone in range.")
            term.gpu().setForeground(temp)

            term.setCursor(a,b)
        end

        modem.broadcast(98,"execute_command","modem.send('" .. modem.address .. "',99,'console_info',drone.getOffset(),computer.energy())")
    end,-1)
end

local timer=add_ping_timer()

-- Global helper for Console User, will be cleaned if program exit normally.
helper={}
function helper.setRadar(enable)
    if(enable) then
        if(timer>0) then
            return "Radar is already on."
        else
            timer=add_ping_timer()
            return "Radar switched on."
        end        
    else
        if(timer>0) then
            RemoveTimer(timer)
            timer=0
            return "Radar switched off."
        else
            return "Radar is already off."
        end
    end
end
helper.target_drone=''
function helper.install_step1()
    modem.broadcast(98,"execute_command","modem.send('" .. modem.address .. "',99,'hide_msg','prepare_for_install')")
    while true do
        local e=WaitEvent(5,"modem_message")
        if(e==nil) then 
            break
        elseif(e.event=="modem_message" and 
            e.port==99 and 
            e.data[1]~=nil and e.data[1]=='hide_msg' and 
            e.data[2]~=nil and e.data[2]=='prepare_for_install') then
                helper.target_drone=e.senderAddress
                SetResponse("[Local] Install step 1: target drone found as: " .. helper.target_drone)
            return true
        end
    end
    SetResponse("[Local] Install step 1: no drone response in 5 seconds.")
    return false
end
helper.drone_lib=[==[
    drone_lib_version='DroneLib v0.1.1'
    move=function(x,y,z,t)
        t=t or 5
        drone.move(x,y,z) 
        while drone.getOffset()>1 do sleep(t) end
    end
    return drone_lib_version .. " successfully installed."
]==]
function helper.install_step2()
    if(helper.target_drone~=nil and string.len(helper.target_drone)>0) then
        SetResponse("[Local] Install step 2: About to perform installation on " .. helper.target_drone)
        os.sleep(1)
        SetResponse("[Local] Install step 2: Sending data to " .. helper.target_drone)
        modem.send(helper.target_drone,98,"execute_command",helper.drone_lib)
    end
end

local history={}
while true do
    local w,h=term.gpu().getResolution()
    term.gpu().fill(1,3,w,h/2-3,' ')
    term.setCursor(1,3)

    local str=term.read(history) -- read a line
    if(str==nil) then break end 

    if(string.sub(str,1,1)=='>') then -- Execute it on this machine
        local ok,err=pcall(function() 
            local fn,err=load(string.sub(str,2))
            if(not fn) then
                SetResponse("[Local] SyntaxError: " .. err)
            else
                local res=fn()
                if(res) then
                    -- type(res) might be "table", which will raise an error here and shutdown the drone console.
                    -- So call it in pcall.
                    SetResponse("[Local] " .. res)
                end
            end
        end)

        if(not ok) then 
            SetResponse("[Local] " .. err)
        end
    else
        modem.broadcast(98,'execute_command',str)
        if(#history>25) then table.remove(history,1) end
    end
end

term.clear()
print("Closing port...")
modem.close(99)
print("Removing listeners...")
RemoveEventListener(listener)
print("Removing timers...")
if(timer>0) then RemoveTimer(timer) end
print("Cleaning up...")
helper=nil