require('libevent')
local component=require('component')
local event=require('event')
local computer=require('computer')
local gpu=component.gpu

print("TimerID is: ",
AddTimer(1,function()
    local str=string.format("<<Listeners: %d RAM: %.1f%%>>",#event.handlers,100-computer.freeMemory()/computer.totalMemory()*100)
    local w,h=gpu.getResolution()
    local startat=w-str:len()
    startat=startat>0 and startat or 1
    gpu.set(startat,1,str)
end,-1)
)