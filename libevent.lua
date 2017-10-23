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