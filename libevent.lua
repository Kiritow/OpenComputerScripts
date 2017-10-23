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
    if(type(Times)~=nil) then -- Timer will run [Times] times.
        checknumber(Times)
        return event.timer(Interval,CallbackFunction,Times)
    else -- Timer will run once.
        return event.timer(Interval,CallbackFunction)
    end
end

function RemoveTimer(TimerID)
    checknumber(TimerID)
    return event.cancel(TimerID)
end
