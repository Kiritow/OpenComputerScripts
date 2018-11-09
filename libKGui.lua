-- LibKGui - Kirito's GUI Library
-- Author: Github/Kiritow

require("libevent")
require("libgpu")
local event=require("event")

local function copy_fn(tbClass,new_obj)
    for k,v in pairs(tbClass) do
        if(type(v)=="function") then 
            new_obj[k]=v
        end
    end
    return new_obj
end

local function Point(x,y)
    return {x=x,y=y}
end

local function Rect(x,y,w,h)
    return {x=x,y=y,w=w,h=h}
end

local function PointInRect(point,rect)
    if(point.x>=rect.x and 
    point.y>=rect.y and 
    point.x<=rect.x+rect.w and
    point.y<=rect.y+rect.h) then return true
    else return false end
end

-- Event callbacks
-- return true to shutdown framework
-- Widget.onclick(this,event)

-- Widget.update(this,gpu): draw and update

Button=
{
    new=function(text,x,y,w,h)
        local t={}
        t.x=x or 1
        t.y=y or 1
        t.w=w or 10
        t.h=h or 2
        t.text=text or "Button"
        t.hidden=false
        
        t.border=0
        t.bordercolor=0xFFFFFF
        t.bcolor=0xFFFFFF
        t.fcolor=0x0
        
        return copy_fn(Button,t)
    end,
    update=function(this,gpu)
        if(not this.hidden) then
            gpu:pushall(this.fcolor,this.bcolor)
            gpu:fill(this.x,this.y,this.w,this.h," ")
            gpu:set(this.y,this.x,this.text)
            gpu:popall()
        end
    end
}

ProgressBar=
{
    new=function(x,y,w,h)
        local t={}
        t.x=x or 1
        t.y=y or 1
        t.w=w or 15
        t.h=h or 1
        t.hidden=false

        t.percent=0.3
        t.bcolor=0x0 -- 70% part
        t.fcolor=0xFFFFFF -- 30% part
        
        return copy_fn(ProgressBar,t)
    end,

    update=function(this,gpu)
        if(not this.hidden) then
            gpu:pushall(this.bcolor,this.bcolor)
            gpu:fill(this.x,this.y,this.w,this.h," ")
            gpu:setfg(this.fcolor)
            gpu:setbg(this.fcolor)
            gpu:fill(this.x,this.y,this.w*this.percent,this.h," ")
            gpu:popall()
        end
    end
}

Framework=
{
    new=function()
        local t={}
        t.widgets={}
        t.listeners={}

        return copy_fn(Framework,t)
    end,

    add=function(this,new_widget)
        if(new_widget._framework) then 
            return false,"widget already in other framework"
        end
        for k,v in pairs(this.widgets) do
            if(v==new_widget) then
               return false,"widget already added"
            end
        end
        table.insert(this.widgets,new_widget)
        new_widget._framework=this
        return true
    end,

    del=function(this,target)
        if((not target._framework) or target._framework~=this) then
            return false,"Widget not associated to this framework"
        end
        for k,v in pairs(this.widgets) do
            if(v==target) then
                table.remove(this.widgets,k)
                target._framework=nil
                return true
            end
        end
        return false,"widget not in list"
    end,

    run=function(this)
        for k,v in pairs(this.listeners) do
            print("Cleaning event listener:",v)
            RemoveEventListener(v)
        end

        if(#this.widgets<1) then
            print("no widgets in set. stopped")
            return 
        end

        local gpu=GetGPU()
        for k,v in pairs(this.widgets) do
            v:update(gpu)
        end
        
        this.listeners={
            AddEventListener("touch",
                function(event)
                    local point=Point(event.x,event.y)
                    for k,v in pairs(this.widgets) do
                        if( v.onclick 
                            and PointInRect(point,Rect(v.x,v.y,v.w,v.h))
                        ) then
                            local need_update,make_stop=v:onclick(e)
                            if(need_update) then 
                                v:update(gpu)
                            end
                            if(make_stop) then
                                PushEvent("framework_stop")
                                break
                            end
                        end
                    end
                end
            ),
            AddEventListener("key_down",
                function(event)
                    for k,v in pairs(this.widgets) do
                        if(v.onkeydown) then 
                            local need_update,make_stop=v:onkeydown(e)
                            if(need_update) then
                                v:update(gpu)
                            end
                            if(make_stop) then
                                PushEvent("framework_stop")
                                break
                            end
                        end
                    end
                end
            )
        }

        print("Framework started.")
        WaitEvent("framework_stop")
        print("About to stop framework...")

        for k,v in pairs(this.listeners) do
            print("Cleaning event listener:",v)
            RemoveEventListener(v)
        end
    end
}