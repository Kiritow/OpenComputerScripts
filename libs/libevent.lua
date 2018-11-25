require("checkarg")
local event=require("event")
local uuid=require("uuid")

-- Internal event translating function table. ex is for custom events.
local internal_evtb={}
local internal_evtbex={}
local _hasInited=false

local function doInternalEventInit()
    if(_hasInited) then 
        return 
    end

    -- tb is a reference to event table.
    local tb=internal_evtb

    tb["component_added"]=function(raw_event,t)
        t["event"]=raw_event[1]
        t["address"]=raw_event[2]
        t["componentType"]=raw_event[3]
    end

    tb["component_removed"]=tb["component_added"]

    tb["component_available"]=function(raw_event,t)
        t["event"]=raw_event[1]
        t["componentType"]=raw_event[2]
    end

    tb["component_unavailable"]=tb["component_available"]

    tb["term_available"]=function(raw_event,t)
        t["event"]=raw_event[1]
    end

    tb["term_unavailable"]=tb["term_available"]

    tb["screen_resized"]=function(raw_event,t)
        t["event"]=raw_event[1]
        t["screenAddress"]=raw_event[2]
        t["newWidth"]=raw_event[3]
        t["newHeight"]=raw_event[4]
    end

    tb["touch"]=function(raw_event,t)
        t["event"]=raw_event[1]
        t["screenAddress"]=raw_event[2]
        t["x"]=raw_event[3]
        t["y"]=raw_event[4]
        t["button"]=raw_event[5]
        t["playerName"]=raw_event[6]
    end

    tb["drag"]=tb["touch"]
    tb["drop"]=tb["touch"]

    tb["scroll"]=function(raw_event,t)
        t["event"]=raw_event[1]
        t["screenAddress"]=raw_event[2]
        t["x"]=raw_event[3]
        t["y"]=raw_event[4]
        t["direction"]=raw_event[5]
        t["playerName"]=raw_event[6]
    end

    tb["walk"]=function(raw_event,t)
        t["event"]=raw_event[1]
        t["screenAddress"]=raw_event[2]
        t["x"]=raw_event[3]
        t["y"]=raw_event[4]
        t["playerName"]=raw_event[5]
    end

    tb["key_down"]=function(raw_event,t)
        t["event"]=raw_event[1]
        t["keyboardAddress"]=raw_event[2]
        t["char"]=raw_event[3]
        t["code"]=raw_event[4]
        t["playerName"]=raw_event[5]
    end

    tb["key_up"]=tb["key_down"]

    tb["clipboard"]=function(raw_event,t)
        t["event"]=raw_event[1]
        t["keyboardAddress"]=raw_event[2]
        t["value"]=raw_event[3]
        t["playerName"]=raw_event[4]
    end

    tb["redstone_changed"]=function(raw_event,t)
        t["event"]=raw_event[1]
        t["address"]=raw_event[2]
        t["side"]=raw_event[3]
        t["oldValue"]=raw_event[4]
        t["newValue"]=raw_event[5]
    end

    tb["motion"]=function(raw_event,t)
        t["event"]=raw_event[1]
        t["address"]=raw_event[2]
        t["relativeX"]=raw_event[3]
        t["relativeY"]=raw_event[4]
        t["relativeZ"]=raw_event[5]
        t["entityName"]=raw_event[6]
    end

    tb["modem_message"]=function(raw_event,t) --- Special
        t["event"]=raw_event[1]
        t["receiverAddress"]=raw_event[2]
        t["senderAddress"]=raw_event[3]
        t["port"]=raw_event[4]
        t["distance"]=raw_event[5]
        t["data"]={}
        for i=6,raw_event.n,1 do 
            t["data"][i-5]=raw_event[i]
        end
        t["data"].n=raw_event.n-5
    end

    tb["inventory_changed"]=function(raw_event,t)
        t["event"]=raw_event[1]
        t["slot"]=raw_event[2]
    end

    tb["bus_message"]=function(raw_event,t) --- Can data or metadata be table?
        t["event"]=raw_event[1]
        t["protocolId"]=raw_event[2]
        t["senderAddress"]=raw_event[3]
        t["targetAddress"]=raw_event[4]
        t["data"]=raw_event[5]
        t["metadata"]=raw_event[6]
    end

    tb["interrupted"]=function(raw_event,t) --- Should soft interrupt be a special event?
        t["event"]=raw_event[1]
        t["uptime"]=raw_event[2]
    end

    --- Computronics
    
    tb["minecart"]=function(raw_event,t)
        t["event"]=raw_event[1]
        t["detectorAddress"]=raw_event[2]
        t["minecartType"]=raw_event[3]
        t["minecartName"]=raw_event[4]
        t["primaryColor"]=raw_event[5]
        t["secondaryColor"]=raw_event[6]
        t["destination"]=raw_event[7]
        t["ownerName"]=raw_event[8]
    end

    tb["aspect_changed"]=function(raw_event,t)
        t["event"]=raw_event[1]
        t["address"]=raw_event[2]
        t["signalName"]=raw_event[3]
        t["signalValue"]=raw_event[4]
    end

    tb["chat_message"]=function(raw_event,t)
        t["event"]=raw_event[1]
        t["address"]=raw_event[2]
        t["username"]=raw_event[3]
        t["message"]=raw_event[4]
    end

    tb["switch_flipped"]=function(raw_event,t)
        t["event"]=raw_event[1]
        t["address"]=raw_event[2]
        t["index"]=raw_event[3]
        t["newState"]=raw_event[4]
    end

    --- OpenSecurity

    tb["magData"]=function(raw_event,t)
        t["event"]=raw_event[1]
        t["address"]=raw_event[2]
        t["user"]=raw_event[3]
        t["content"]=raw_event[4]
        t["uuid"]=raw_event[5]
        t["locked"]=raw_event[6]
        t["side"]=raw_event[7]
    end

    tb["cardInsert"]=function(raw_event,t)
        t["event"]=raw_event[1]
        t["address"]=raw_event[2]
    end

    tb["cardRemove"]=tb["cardInsert"]

    tb["keypad"]=function(raw_event,t)
        t["event"]=raw_event[1]
        t["address"]=raw_event[2]
        t["id"]=raw_event[3]
        t["label"]=raw_evnet[4]
    end

    tb["bioReader"]=function(raw_event,t)
        t["event"]=raw_event[1]
        t["address"]=raw_event[2]
        t["uuid"]=raw_event[3]
    end

    --- LibNetBox

    tb["net_message"]=function(raw_event,t)
        t["event"]=raw_event[1]
        t["receiverAddress"]=raw_event[2]
        t["senderAddress"]=raw_event[3]
        t["port"]=raw_event[4]
        t["data"]={}
        for i=5,raw_event.n,1 do 
            t["data"][i-4]=raw_event[i]
        end
        t["data"].n=raw_event.n-4;
    end

    -- Mark as inited.
    _hasInited=true
end

local function TranslateEvent(raw_event)
    if(raw_event==nil) then return nil end

    local t={}
    local name=raw_event[1]
    if(name==nil) then return nil end

    t["event"]=name

    -- Standard Events
    if(internal_evtb[name]~=nil) then
        internal_evtb[name](raw_event,t)
    -- External Events
    elseif(internal_evtbex[name]~=nil) then
        internal_evtbex[name](raw_event,t)
    -- Unknown Events. Args is packed into t.data (instead of returning the list)
    else
        t["data"]=table.pack(raw_event,2)
    end

    setmetatable(t,{__index=function(xt,xk)
        local xname=rawget(xt,"event")
        if(xname==nil) then xname="<unknown>" end
        error("Event " .. xname .. " does not have member:" .. xk)
    end})

    return t
end

function SetEventTranslator(event_name,callback)
    checkstring(event_name)
    if(callback~=nil) then 
        checkfunction(callback) 
    end 
    internal_evtbex[event_name]=callback
end

function AddEventListener(EventName,CallbackFunction)
    checkstring(EventName)
    checkfunction(CallbackFunction)
    return event.listen(EventName,
        function(...)
            local raw_event=table.pack(...)
            local rt=table.pack(TranslateEvent(raw_event))
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

-- Usage: WaitEventEx([timeout],[event name],[other filter value])
-- Example: WaitEventEx() WaitEventEx(1) WaitEventEx("touch") WaitEventEx(1,"touch")
--          WaitEventEx("touch",nil,nil,"somebody")
--          WaitEventEx(1,"touch",nil,nil,"somebody")
function WaitEventEx(...)
    return TranslateEvent(table.pack(event.pull(...)))
end

-- Usage: WaitEvent([timeout],[event name]) or
--        WaitEvent([event name],[timeout]) -- Fallback usage
function WaitEvent(a,b)
    if(a==nil) then
        return WaitEventEx()
    elseif(type(a)=="string") then
        if(b==nil) then
            return WaitEventEx(a)
        elseif(type(b)=="number") then
            return WaitEventEx(b,a)
        else
            error("Second param must be number or nil")
        end
    elseif(type(a)=="number") then
        if(b==nil) then
            return WaitEventEx(a)
        elseif(type(b)=="string") then
            return WaitEventEx(a,b)
        else
            error("Second param must be string or nil")
        end
    else
        error("First param must be string or number or nil")
    end
end

-- Usage: WaitMultipleEvent([timeout],Event1,Event2,...)
function WaitMultipleEvent(...)
    -- event.pullMultiple will check the param
    return TranslateEvent(table.pack(event.pullMultiple(...)))
end

function PushEvent(EventName,...)
    checkstring(EventName)
    return event.push(EventName,...)
end

function AddTimer(Interval,CallbackFunction,Times)
    checknumber(Interval)
    checkfunction(CallbackFunction)
    checknumber(Times) 

    -- If times==0, just don't add it.

    if(Times<0) then -- Timer will infinitly run (when times <0)
        return event.timer(Interval,CallbackFunction,math.huge)
    elseif(Times>0) then -- Timer will run [Times] times.
        return event.timer(Interval,CallbackFunction,Times)
    end
end

function RemoveTimer(TimerID)
    checknumber(TimerID)
    return event.cancel(TimerID)
end

--- EventBus: Queued event bus.
--- Notice that event bus can only handle event packages.
function EventBusListen(t,event_name,checkfn)
    checktable(t)
    checkstring(event_name)
    if(checkfn~=nil and type(checkfn)=="function") then
        table.insert(t.listeners,
            AddEventListener(event_name,
                function(epack)
                    if(checkfn(epack)) then
                        table.insert(t.events,epack)
                    end
                end
            )
        )
    else
        table.insert(t.listeners,
            AddEventListener(event_name,
                function(epack)
                    table.insert(t.events,epack)
                end
            )
        )
    end
end

function GetNextEvent(t,wait_second,wait_ratio)
    checktable(t)
    if(wait_second~=nil) then
        checknumber(wait_second)
    else
        -- This has caused thousands of error! Now, without wait_second, by default, it means wait infinitely.
        -- If you want a non-blocking check, call GetNextEvent(bus,0) instead!
        wait_second=-1
    end

    if(wait_ratio~=nil) then
        checknumber(wait_ratio)

        if(wait_ratio>1) then
            wait_ratio=1/wait_ratio
        end
        
        if(wait_ratio<0.05) then
            error("Wait ratio should greater than 0.05. (cps less than 20)")
        end
    else
        wait_ratio=1
    end

    if(t.events[1]~=nil) then
        local e=t.events[1]
        table.remove(t.events,1)
        return e
    else
        if(wait_second<0) then
            while t.events[1]==nil do
                os.sleep(wait_ratio)
            end
        else
            local wait_second_left=wait_second
            while t.events[1]==nil and wait_second_left>0 do 
                os.sleep(wait_ratio)
                wait_second_left=wait_second_left-wait_ratio
            end
        end

        if(t.events[1]~=nil) then 
            local e=t.events[1]
            table.remove(t.events,1)
            return e
        else
            return nil
        end
    end
end

function DestroyEventBus(t)
    for k,v in pairs(t.listeners) do
        RemoveEventListener(v)
    end
    t.listeners={}
    t.events={}
end

function CreateEventBus()
    return 
    {
        listeners={},
        events={},
        -- Enable using t:listen(...)
        listen=EventBusListen,
        next=GetNextEvent,
        close=DestroyEventBus,
        -- Deprecated
        reset=DestroyEventBus
    }
end

--- Init Library on load
doInternalEventInit()