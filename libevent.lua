require("checkarg")
local event=require("event")

function AddEventListener(EventName,CallbackFunction)
    checkstring(EventName)
    checkfunction(CallbackFunction)
    return event.listen(EventName,CallbackFunction)
end

function RemoveEventListener(ListenerID)
    checknumber(ListenerID)
    return event.ignore(event.handlers[ListenerID].key,event.handlers[ListenerID].callback)
end

function WaitEvent(EventName)
    checkstring(EventName)
    return event.pull(EventName)
end

function WaitEventFor(EventName,TimeOut)
    checkstring(EventName)
    checknumber(TimeOut)
    return event.pull(TimeOut,EventName)
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
