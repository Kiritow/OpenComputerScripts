-- Drone Radar
-- Created by Kiritow.
local component=require('component')
local computer=require('computer')
local term=require('term')
local text=require('text')

require("libevent")

local radar_version="Drone Radar v0.1.3"
local modem=component.modem
local gpu=term.gpu()

local function status(msg)
    local w,h=gpu.getResolution()
    gpu.set(1,h,"Status: " .. msg)
end

term.clear()
print("Drone Radar")
print("Checking hardware...")
if(modem==nil) then
    print("This program requires a modem component to work")
    return
end
print("Opening modem port...")
if(not modem.open(99)) then
    if(modem.isOpen(99)) then
        print("Port 99 is already opened.")
    else
        print("Unable to open port 99.")
        return
    end
end
print("Adding timer...")
local broadcast_intv=8
local timer=AddTimer(broadcast_intv,function()
    modem.broadcast(98,"execute_command","modem.send('" .. modem.address .. "',99,'radar_info',drone.getOffset(),computer.energy())")
end,-1)
print("Adding listener...")
local tb_drone={}
local listener=AddEventListener("modem_message",function(e)
    if(e.port==99 and e.data[1]=='radar_info') then
        tb_drone[e.senderAddress]={
            distance=e.distance,
            offset=e.data[2],
            energy=e.data[3],
            update=computer.uptime()
        }
        PushEvent("radar_gui_update")
    end
end)

local function show_tb(tb)
    local maxLen={}
    for idx,v in ipairs(tb) do 
        for nidx,val in ipairs(v) do
            if(not maxLen[nidx] or maxLen[nidx]<string.len(val)) then
                maxLen[nidx]=string.len(val)
            end
        end
    end
    for idx,v in ipairs(tb) do
        for nidx,val in ipairs(v) do
            v[nidx]=text.padRight(val,maxLen[nidx])
        end
        print(table.concat(v," "))
    end
end

term.clear()
print(radar_version)

while true do
    term.setCursor(1,2)
    local now=computer.uptime()
    local show={}
    table.insert(show,{"Address","Status","Distance","Offset","Energy"})
    for addr,tb in pairs(tb_drone) do
        local newt={string.sub(addr,1,8),"[Missing]",string.format("%.1f",tb.distance),string.format("%.1f",tb.offset),string.format("%.1f",tb.energy)}
        if(now-tb.update<broadcast_intv) then 
            if(tb.offset<1) then
                newt[2]="[OK]"
            else
                newt[2]="[Flying]"
            end
        end
        table.insert(show,newt)

        if(now-tb.update>broadcast_intv*2.5) then
            tb_drone[addr]=nil
        end
    end
    show_tb(show)
    local e=WaitMultipleEvent("interrupted","radar_gui_update")
    if(e.event=="interrupted") then break end
end

term.clear()
print("Stopping listener...")
RemoveEventListener(listener)
print("Stopping timer...")
RemoveTimer(timer)
print("Closing port...")
modem.close(99)