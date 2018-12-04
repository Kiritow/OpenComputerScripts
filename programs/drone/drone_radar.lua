-- Passive Drone Radar
-- Created by Kiritow.
local component=require('component')
local computer=require('computer')
local term=require('term')
local text=require('text')

require("libevent")

local radar_version="Passive Drone Radar v0.1.5"
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
print("Adding listener...")
local tb_drone_old={}
local tb_drone_new={}
local listener=AddEventListener("modem_message",function(e)
    if(e.port==99 and e.data[1]=='drone_info') then
        tb_drone_old[e.senderAddress]=tb_drone_new[e.senderAddress]
        tb_drone_new[e.senderAddress]={
            distance=e.distance,
            offset=e.data[2],
            energy=e.data[3],
            update=computer.uptime()
        }
        PushEvent("radar_gui_update")
    end
end)

local function show_tb(gpu,tb)
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
        gpu.set(1,1+idx,table.concat(v," "))
    end
end

term.clear()
print(radar_version)

while true do
    local w,h=gpu.getResolution()
    gpu.fill(1,2,w,h-1,' ')
    local now=computer.uptime()
    local show={}
    table.insert(show,{"Address","Status","Distance","Offset","Energy"})
    for addr,tb in pairs(tb_drone_new) do
        local newt={string.sub(addr,1,8),"[Missing]",string.format("%.1f",tb.distance),string.format("%.1f",tb.offset),string.format("%.1f",tb.energy)}
        if(now-tb.update<broadcast_intv) then 
            if(tb.offset<1) then
                newt[2]="[OK]"
            else
                if(tb_drone_old[addr]) then
                    local diff=tb_drone_new[addr].distance-tb_drone_old[addr].distance
                    if(diff>0) then
                        newt[2]="[Flying away]"
                    elseif(diff<0) then
                        newt[2]="[Flying in]"
                    end
                else
                    newt[2]="[Flying]"
                end
            end
        end
        table.insert(show,newt)

        if(now-tb.update>broadcast_intv*2.5) then
            tb_drone_new[addr]=nil
            tb_drone_old[addr]=nil
        end
    end
    show_tb(gpu,show)
    local e=WaitMultipleEvent("interrupted","radar_gui_update")
    if(e.event=="interrupted") then break end
end

term.clear()
print("Stopping listener...")
RemoveEventListener(listener)
print("Closing port...")
modem.close(99)