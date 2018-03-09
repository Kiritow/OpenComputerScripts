-- Kiritow's GUI Library
-- Author: Github/Kiritow

local component=require("component")

local function GPUClear(t)
    local w,h=t.gpu.getResolution()
    t.gpu.fill(1,1,w,h," ")
end

local function GPUSet(t,line,col,str)
    t.gpu.set(col,line,str)
end

local function GPUGet(t,line,col)
    return t.gpu.get(col,line)
end

-- API
function GetGPU()
    if(component.gpu==nil) then
        error("No GPU Found.")
    else
        local t={}
        t.gpu=component.gpu
        t.clear=GPUClear
        t.set=GPUSet
        t.get=GPUGet
        return t
    end
end