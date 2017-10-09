local component=require("component")

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
        print("Query List is Empty")
        return nil
    elseif(sz==1) then
        for k in pairs(t) do
            return rawproxy(k)
        end
    else
        if(beginWith == nil) then
            print("No beginWith value")
            return nil
        end
        if(type(beginWith) ~= "string") then
            print("beginWith is not string")
            return nil
        end
        local bsz=string.len(beginWith)
        for k in pairs(t) do
            if(string.sub(k,1,bsz) == beginWith) then
                return rawproxy(k)
            end
        end
        print("Not found with beginWith value")
        return nil
    end
end
