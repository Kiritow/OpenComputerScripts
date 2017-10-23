local event=require("event")

function AddEventListener(EventString,CallbackFunction)
    return event.listen(EventString,CallbackFunction)
end

function RemoveEventListener(ListenerID)
    return event.ignore(event.handlers[ListenerID].key,event.handlers[ListenerID].callback)
end