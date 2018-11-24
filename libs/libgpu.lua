-- LibGPU - A library help operating GPU.
-- Author: Github/Kiritow

local component=require("component")

-- y is line, x is col

local function GPUClear(t)
    local w,h=t.gpu.getResolution()
    t.gpu.fill(1,1,w,h," ")
end

local function GPUFill(t,x,y,w,h,char_str)
    if(string.len(char_str)>1) then 
        char_str=string.sub(char_str,1,1)
    end
    t.gpu.fill(x,y,w,h,char_str)
end

local function GPUSet(t,line,col,str)
    t.gpu.set(col,line,str)
end

local function GPUGet(t,line,col)
    return t.gpu.get(col,line)
end

local function GPUSetColorFG(t,rgb)
    t.gpu.setForeground(rgb)
end

local function GPUSetColorBG(t,rgb)
    t.gpu.setBackground(rgb)
end

local function GPUGetColorFG(t)
    return t.gpu.getForeground()
end

local function GPUGetColorBG(t)
    return t.gpu.getBackground()
end

-- Store current fg, then set fg to rgb
local function GPUPushFG(t,rgb)
    t.fgstk[t.fgstk.n+1]=t:getfg()
    t.fgstk.n=t.fgstk.n+1
    t:setfg(rgb)
end

local function GPUPopFG(t)
    t:setfg(t.fgstk[t.fgstk.n])
    t.fgstk[t.fgstk.n]=nil
    t.fgstk.n=t.fgstk.n-1
end

local function GPUPushBG(t,rgb)
    t.bgstk[t.bgstk.n+1]=t:getbg()
    t.bgstk.n=t.bgstk.n+1
    t:setbg(rgb)
end

local function GPUPopBG(t)
    t:setbg(t.bgstk[t.bgstk.n])
    t.bgstk[t.bgstk.n]=nil
    t.bgstk.n=t.bgstk.n-1
end

local function GPUPushAll(t,fg_rgb,bg_rgb)
    GPUPushFG(t,fg_rgb)
    GPUPushBG(t,bg_rgb)
end

local function GPUPopAll(t)
    GPUPopBG(t)
    GPUPopFG(t)
end

-- API
function GetGPU(addr)
    if(component.list("gpu")==nil) then
        error("No GPU Found.")
    else
        local t={}
        t.gpu=component.proxy(component.list("gpu")())
        t.clear=GPUClear
        t.set=GPUSet
        t.get=GPUGet
        t.fill=GPUFill
        t.setfg=GPUSetColorFG
        t.getfg=GPUGetColorFG
        t.setbg=GPUSetColorBG
        t.getbg=GPUGetColorBG
        t.fgstk={n=0}
        t.bgstk={n=0}
        t.pushfg=GPUPushFG
        t.popfg=GPUPopFG
        t.pushbg=GPUPushBG
        t.popbg=GPUPopBG
        t.pushall=GPUPushAll
        t.popall=GPUPopAll
        return t
    end
end