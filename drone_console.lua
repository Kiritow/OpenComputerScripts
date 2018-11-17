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
print('Drone Debug Console v1.4.2')
print('Command Prompt (Ctrl+D to exit)')

local last_response=computer.uptime()

local listener=AddEventListener("modem_message",function(e) 
    if(e.data[1]~=nil and e.data[1]=='console_info') then
        last_response=computer.uptime()

        local a,b=term.getCursor()

        local w,h=term.gpu().getResolution()
        term.gpu().fill(1,h,w,1,' ')
        local text="distance: " .. e.distance .. " offset: " .. e.data[2] .. " energy:"
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
    elseif(e.data[1]~=nil) then
        local a,b=term.getCursor()

        local w,h=term.gpu().getResolution()
        term.gpu().fill(1,h/2,w,h/2-3,' ')
        
        term.setCursor(1,h/2)
        print("Remote Response")
        print(e.data[1])

        term.setCursor(a,b)
    end -- nil response are not rendered.
end)

local timer=AddTimer(5,function()
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

local history={}

while true do
    local w,h=term.gpu().getResolution()
    term.gpu().fill(1,3,w,h/2-3,' ')
    term.setCursor(1,3)

    local str=term.read(history) -- read a line
    if(str==nil) then break end 
    modem.broadcast(98,'execute_command',str)
    if(#history>25) then table.remove(history,1) end
end

term.clear()
print("Closing port...")
modem.close(99)
print("Removing listeners...")
RemoveEventListener(listener)
print("Removing timers...")
RemoveTimer(timer)
