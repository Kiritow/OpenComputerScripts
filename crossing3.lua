require("libevent")
require("util")
local component=require("component")
local computer=require("computer")

-- Hardware
local drecv=proxy("digital_receiver_box")
local dsend=proxy("digital_controller_box")

local SA=proxy("digital_detector","6")
local SB=proxy("digital_detector","9")
local SC=proxy("digital_detector","2")

local nameA="StationA"
local nameB="StationB"
local nameC="StationC"

--[[
    getAspect/setAspect: 1 Green 3 Yellow 5 Red
    SigIn : LAIN LAOUT LBIN LBOUT LCIN LCOUT 
    SigOut: KA MA KB MB KC MC
    Device: SA SB SC
]]

local green=1
local yellow=3
local red=5

local function getSignal(name)
    return drecv.getAspect(name)
end

local function setSignal(name,val)
    dsend.setAspect(name,val)
end

local function resetSystem()
    setSignal("KA",red)
    setSignal("KB",red)
    setSignal("KC",red)
    setSignal("MA",red)
    setSignal("MB",red)
    setSignal("MC",red)
end

local function getOperation(trainID,from)
    return math.random(0,1)
end

local function main()
    resetSystem()
    local bus=CreateEventBus()
    bus:listen("minecart",function(e)
        return (string.find(e.minecartType,"locomotive")~=nil)
    end)
    bus:listen("interrupted")

    while true do
        print("Waiting event...")
        local e=bus:next()
        if(e.event=="interrupted") then break end

        -- Try to solve
        local ans=-1
        if(e.detectorAddress==SA.address) then
            print("A-->?")
            ans=getOperation(e.destination,nameA)
        elseif(e.detectorAddress==SB.address) then
            print("B-->?")
            ans=getOperation(e.destination,nameB)
        elseif(e.detectorAddress==SC.address) then
            print("C-->?")
            ans=getOperation(e.destination,nameC)
        end

        local solved=false

        if(ans==-1) then
            print("Unknown Train")
        elseif(ans==0) then
            if(e.detectorAddress==SA.address) then
                if(getSignal("LBIN")==green) then
                    print("A-->B")
                    setSignal("MA",red)
                    setSignal("KA",green)
                    WaitEventEx("aspect_changed",nil,"LBIN")
                    setSignal("KA",red)
                    solved=true
                end
            elseif(e.detectorAddress==SB.address) then
                if(getSignal("LAIN")==green) then
                    print("B-->A")
                    setSignal("MB",red)
                    setSignal("KB",green)
                    WaitEventEx("aspect_changed",nil,"LAIN")
                    setSignal("KB",red)
                    solved=true
                end
            elseif(e.detectorAddress==SC.address) then
                if(getSignal("LAIN")==green) then
                    print("C-->A")
                    setSignal("MB",red)
                    setSignal("MC",red)
                    setSignal("KC",green)
                    WaitEventEx("aspect_changed",nil,"LAIN")
                    setSignal("KC",red)
                    solved=true
                end
            end
        elseif(ans==1) then
            if(e.detectorAddress==SA.address) then
                if(getSignal("LCIN")==green) then
                    print("A-->C")
                    setSignal("MA",green)
                    setSignal("KA",green)
                    WaitEventEx("aspect_changed",nil,"LCIN")
                    setSignal("KA",red)
                    solved=true
                end
            elseif(e.detectorAddress==SB.address) then
                if(getSignal("LCIN")==green) then
                    print("B-->C")
                    setSignal("MB",green)
                    setSignal("KB",green)
                    WaitEventEx("aspect_changed",nil,"LCIN")
                    setSignal("KB",red)
                    solved=true
                end
            elseif(e.detectorAddress==SC.address) then
                if(getSignal("LBIN")==green) then
                    print("C-->B")
                    setSignal("MC",green)
                    setSignal("KC",green)
                    WaitEventEx("aspect_changed",nil,"LBIN")
                    setSignal("KC",red)
                    solved=true
                end
            end
        end

        if(not solved) then
            table.insert(bus.events,e)
            os.sleep(0.5)
        end
    end

    resetSystem()
end

print("Program Started")
main()
print("Program Stopped")