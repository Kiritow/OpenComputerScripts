require("checkarg")
local event=require("event")

local internal_evtb={}

local function canEventTranslate(name)
    for k,v in pairs(internal_evtb) do 
        if(k==name) then 
            return true
        end
    end 
    return false
end

local function doEventCustomTranslate(raw_event,t)
    local name=raw_event[1]
    local call=internal_evtb[name]
    call(raw_event,t)
end

local function doEventTranslate(raw_event)
    local t={}
    local nop=0

    local name=raw_event[1]
    local a=raw_event[2]
    local b=raw_event[3]
    local c=raw_event[4]
    local d=raw_event[5]
    local e=raw_event[6]
    local f=raw_event[7]
    local g=raw_event[8]

    t["event"]=name

    if(name=="component_added" or name=="component_removed") then
        t["address"]=a
        t["componentType"]=b
    elseif(name=="component_available" or name=="component_unavailable") then
        t["componentType"]=a
    elseif(name=="term_available" or name=="term_unavailable") then
        nop=nop+1
    elseif(name=="screen_resized") then 
        t["screenAddress"]=a
        t["newWidth"]=b
        t["newHeight"]=c
    elseif(name=="touch" or name=="drag" or name=="drop") then
        t["screenAddress"]=a
        t["x"]=b
        t["y"]=c
        t["button"]=d
        t["playerName"]=e
    elseif(name=="scroll") then
        t["screenAddress"]=a
        t["x"]=b
        t["y"]=c
        t["direction"]=d
        t["playerName"]=e
    elseif(name=="walk") then 
        t["screenAddress"]=a
        t["x"]=b
        t["y"]=c
        t["playerName"]=d
    elseif(name=="key_down" or name=="key_up") then
        t["keyboardAddress"]=a
        t["char"]=b
        t["code"]=c
        t["playerName"]=d
    elseif(name=="clipboard") then
        t["keyboardAddress"]=a
        t["value"]=b
        t["playerName"]=c
    elseif(name=="redstone_changed") then
        t["address"]=a
        t["side"]=b
        t["oldValue"]=c
        t["newValue"]=d
    elseif(name=="motion") then 
        t["address"]=a
        t["relativeX"]=b
        t["relativeY"]=c
        t["relativeZ"]=d
        t["entityName"]=e
    elseif(name=="modem_message") then --- Special
        t["receiverAddress"]=a
        t["senderAddress"]=b
        t["port"]=c
        t["distance"]=d
        local dtb={}
        for i=6,raw_event.n,1 do 
            table.insert(dtb,raw_event[i])
        end
        t["data"]=dtb
    elseif(name=="inventory_changed") then 
        t["slot"]=a
    elseif(name=="bus_message") then
        t["protocolId"]=a
        t["senderAddress"]=b
        t["targetAddress"]=c
        t["data"]=d
        t["metadata"]=e
    elseif(name=="minecart") then
        t["detectorAddress"]=a
        t["minecartType"]=b
        t["minecartName"]=c
        t["primaryColor"]=d
        t["secondaryColor"]=e
        t["destination"]=f
        t["ownerName"]=g
    elseif(name=="aspect_changed") then
        t["address"]=a
        t["signalName"]=b
        t["signalValue"]=c
    else -- Unknown Event
        if(canEventTranslate(name)) then -- Try Translate
            doEventCustomTranslate(raw_event,t)
        else -- Cannot Translate
            return table.unpack(raw_event)
        end
    end

    return t
end

function SetEventTranslator(event_name,callback)
    checkstring(event_name)
    if(callback~=nil) then 
        checkfunction(callback) 
    end 
    internal_evtb[event_name]=callback
end

function AddEventListener(EventName,CallbackFunction)
    checkstring(EventName)
    checkfunction(CallbackFunction)
    return event.listen(EventName,
        function(...)
            local raw_event=table.pack(...)
            local rt=table.pack(doEventTranslate(raw_event))
            if(type(rt[1])=="table") then
                return CallbackFunction(rt[1])
            else
                return CallbackFunction(table.unpack(rt))
            end
        end)
end

function RemoveEventListener(ListenerID)
    checknumber(ListenerID)
    return event.ignore(event.handlers[ListenerID].key,event.handlers[ListenerID].callback)
end

function WaitEvent(EventName)
    if(EventName~=nil) then 
        checkstring(EventName)
        return doEventTranslate(table.pack(event.pull(EventName)))
    else
        return doEventTranslate(table.pack(event.pull()))
    end
end

function WaitEventFor(EventName,TimeOut)
    checkstring(EventName)
    checknumber(TimeOut)
    return doEventTranslate(table.pack(event.pull(TimeOut,EventName)))
end

function PushEvent(EventName,...)
    checkstring(EventName)
    return event.push(EventName,...)
end

function AddTimer(Interval,CallbackFunction,Times)
    checknumber(Interval)
    checkfunction(CallbackFunction)
    checknumber(Times) 
    if(Times<1) then -- Timer will infinitly run (when times <0)
        return event.timer(Interval,CallbackFunction,math.huge)
    else -- Timer will run [Times] times.
        return event.timer(Interval,CallbackFunction,Times)
    end
end

function RemoveTimer(TimerID)
    checknumber(TimerID)
    return event.cancel(TimerID)
end
