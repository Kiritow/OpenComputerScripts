local component=require("component")
local serialization = require("serialization")

function serialize(value)
    return serialization.serialize(value)
end

function unserialize(str)
    return serialization.unserialize(str)
end

function getTableSize(t)
    local cnt=0
    for k in pairs(t) do 
        cnt=cnt+1
        end
    return cnt
end

function isTableEmpty(t)
    return getTableSize(t) == 0
end

function rawproxy(id)
    return component.proxy(id)
end

function proxy(componentType,beginWith)
    local t=component.list(componentType)
    local sz=getTableSize(t)
    if(sz==0) then
        print("proxy: Query List is Empty")
        return nil
    elseif(sz==1) then
        for k in pairs(t) do
            return rawproxy(k)
        end
    else
        if(beginWith == nil) then
            print("proxy: beginWith value required.")
            return nil
        end
        if(type(beginWith) ~= "string") then
            print("proxy: beginWith is not string")
            return nil
        end
        local bsz=string.len(beginWith)
        local traw
        local cnt=0
        for k in pairs(t) do
            if(string.sub(k,1,bsz) == beginWith) then
                if(cnt==0) then 
                    traw=rawproxy(k)
                    cnt=1
                else
                    print("proxy: Found more than 1 target.")
                    return nil
                end
            end
        end

        if(cnt==0) then 
            print("proxy: Not found with beginWith value")
            return nil
        else
            return traw
        end
    end
end
