require("checkarg")
local event=require("event")

local libevent_version="LibEvent 20190111-1655"

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

    tb["component_added"]=function(e,t)
        t["event"]=e[1]
        t["address"]=e[2]
        t["type"]=e[3]

        t["componentType"]=e[3]
    end

    tb["component_removed"]=tb["component_added"]

    tb["component_available"]=function(e,t)
        t["event"]=e[1]
        t["type"]=e[2]

        t["componentType"]=e[2]
    end

    tb["component_unavailable"]=tb["component_available"]

    tb["term_available"]=function(e,t)
        t["event"]=e[1]
    end

    tb["term_unavailable"]=tb["term_available"]

    tb["screen_resized"]=function(e,t)
        t["event"]=e[1]
        t["address"]=e[2]
        t["width"]=e[3]
        t["height"]=e[4]

        t["screenAddress"]=e[2]
        t["newWidth"]=e[3]
        t["newHeight"]=e[4]
    end

    tb["touch"]=function(e,t)
        t["event"]=e[1]
        t["address"]=e[2]
        t["x"]=e[3]
        t["y"]=e[4]
        t["button"]=e[5]
        t["player"]=e[6]

        t["screenAddress"]=e[2]
        t["playerName"]=e[6]
    end

    tb["drag"]=tb["touch"]
    tb["drop"]=tb["touch"]

    tb["scroll"]=function(e,t)
        t["event"]=e[1]
        t["address"]=e[2]
        t["x"]=e[3]
        t["y"]=e[4]
        t["direction"]=e[5]
        t["player"]=e[6]

        t["screenAddress"]=e[2]
        t["playerName"]=e[6]
    end

    tb["walk"]=function(e,t)
        t["event"]=e[1]
        t["address"]=e[2]
        t["x"]=e[3]
        t["y"]=e[4]
        t["player"]=e[5]

        t["screenAddress"]=e[2]
        t["playerName"]=e[5]
    end

    tb["key_down"]=function(e,t)
        t["event"]=e[1]
        t["address"]=e[2]
        t["char"]=e[3]
        t["code"]=e[4]
        t["player"]=e[5]

        t["keyboardAddress"]=e[2]
        t["playerName"]=e[5]
    end

    tb["key_up"]=tb["key_down"]

    tb["clipboard"]=function(e,t)
        t["event"]=e[1]
        t["address"]=e[2]
        t["value"]=e[3]
        t["player"]=e[4]

        t["keyboardAddress"]=e[2]
        t["playerName"]=e[4]
    end

    tb["redstone_changed"]=function(e,t)
        t["event"]=e[1]
        t["address"]=e[2]
        t["side"]=e[3]
        t["oldValue"]=e[4]
        t["newValue"]=e[5]
    end

    tb["motion"]=function(e,t)
        t["event"]=e[1]
        t["address"]=e[2]
        t["x"]=e[3]
        t["y"]=e[4]
        t["z"]=e[5]
        t["entityName"]=e[6]

        t["relativeX"]=e[3]
        t["relativeY"]=e[4]
        t["relativeZ"]=e[5]
    end

    tb["modem_message"]=function(e,t) --- Special
        t["event"]=e[1]
        t["receiver"]=e[2]
        t["sender"]=e[3]
        t["port"]=e[4]
        t["distance"]=e[5]
        t["data"]={}
        for i=6,e.n,1 do 
            t["data"][i-5]=e[i]
        end
        t["data"].n=e.n-5

        t["receiverAddress"]=e[2]
        t["senderAddress"]=e[3]
    end

    tb["inventory_changed"]=function(e,t)
        t["event"]=e[1]
        t["slot"]=e[2]
    end

    tb["bus_message"]=function(e,t)
        t["event"]=e[1]
        t["protocolId"]=e[2]
        t["senderAddress"]=e[3]
        t["targetAddress"]=e[4]
        t["data"]=e[5]
        t["metadata"]=e[6]
    end

    tb["interrupted"]=function(e,t)
        t["event"]=e[1]
        t["uptime"]=e[2]
    end

    --- Computronics
    
    tb["minecart"]=function(e,t)
        t["event"]=e[1]
        t["detectorAddress"]=e[2]
        t["minecartType"]=e[3]
        t["minecartName"]=e[4]
        t["primaryColor"]=e[5]
        t["secondaryColor"]=e[6]
        t["destination"]=e[7]
        t["ownerName"]=e[8]
    end

    tb["aspect_changed"]=function(e,t)
        t["event"]=e[1]
        t["address"]=e[2]
        t["signalName"]=e[3]
        t["signalValue"]=e[4]
    end

    tb["chat_message"]=function(e,t)
        t["event"]=e[1]
        t["address"]=e[2]
        t["username"]=e[3]
        t["message"]=e[4]
    end

    tb["switch_flipped"]=function(e,t)
        t["event"]=e[1]
        t["address"]=e[2]
        t["index"]=e[3]
        t["newState"]=e[4]
    end

    --- OpenSecurity

    tb["magData"]=function(e,t)
        t["event"]=e[1]
        t["address"]=e[2]
        t["user"]=e[3]
        t["content"]=e[4]
        t["uuid"]=e[5]
        t["locked"]=e[6]
        t["side"]=e[7]
    end

    tb["cardInsert"]=function(e,t)
        t["event"]=e[1]
        t["address"]=e[2]
    end

    tb["cardRemove"]=tb["cardInsert"]

    tb["keypad"]=function(e,t)
        t["event"]=e[1]
        t["address"]=e[2]
        t["id"]=e[3]
        t["label"]=e[4]
    end

    tb["bioReader"]=function(e,t)
        t["event"]=e[1]
        t["address"]=e[2]
        t["uuid"]=e[3]
    end

    -- OpenGlasses

    tb["glasses_on"]=function(e,t)
        t["user"]=e[1]
    end

    tb["glasses_off"]=tb["glasses_on"]

    tb["interact_world_left"]=function(e,t)
        t["event"]=e[1]
        t["address"]=e[2]
        t["user"]=e[3]
        t["pos"]={
            ["x"]=e[4],
            ["y"]=e[5],
            ["z"]=e[6]
        }
        t["look"]={
            ["x"]=e[7],
            ["y"]=e[8],
            ["z"]=e[9]
        }
        t["eyeHeight"]=e[10]
    end

    tb["interact_world_right"]=tb["interact_world_left"]

    tb["interact_overlay"]=function(e,t)
        t["event"]=e[1]
        t["address"]=e[2]
        t["user"]=e[3]
        t["button"]=e[4]
        t["x"]=e[5]
        t["y"]=e[6]
        t["width"]=e[7]
        t["height"]=e[8]
    end

    --- LibNetBox

    tb["net_message"]=function(e,t)
        t["event"]=e[1]
        t["receiverAddress"]=e[2]
        t["senderAddress"]=e[3]
        t["port"]=e[4]
        t["data"]={}
        for i=5,e.n,1 do 
            t["data"][i-4]=e[i]
        end
        t["data"].n=e.n-4;
    end

    -- Mark as inited.
    _hasInited=true
end

-- Always return event pack or nil.
local function TranslateEvent(e)
    -- nil or named nil
    if(not e or not e[1]) then return nil end

    local t={}
    local name=e[1]
    t["event"]=name

    -- Standard Events
    if(internal_evtb[name]~=nil) then
        internal_evtb[name](e,t)
    -- External Events
    elseif(internal_evtbex[name]~=nil) then
        internal_evtbex[name](e,t)
    -- Unknown Events. Args is packed into t.data (instead of returning the list)
    else
        t["data"]=table.pack(table.unpack(e, 2))
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
    local old=internal_evtbex[event_name]
    internal_evtbex[event_name]=callback
    return old
end

function AddEventListener(EventName,CallbackFunction)
    checkstring(EventName)
    checkfunction(CallbackFunction)
    return event.listen(EventName,
        function(...)
            local e=TranslateEvent(table.pack(...))
            if(e) then
                return CallbackFunction(e)
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

return libevent_version