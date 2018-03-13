-- LibGUI - A library for developing software with GUI
-- Author: Github/Kiritow

require("class")
require("libevent")
require("libgpu")

Button=class("Button")

function Button:ctor()
    self.x=1
    self.y=1
    self.w=10
    self.h=2
    self.hide=false

    self.bordered=false
    self.bcolor=0x0
    self.fcolor=0xFFFFFF
    self.text=""
end

function Button:update(gpu)
    for i=self.y,self.y+self.h,1 do
        for j=self.x,self.x+self.w,1 do
            gpu:set(i,j," ")
        end
    end
end


ProgressBar=class("ProgressBar")

function ProgressBar:ctor()
    self.x=1
    self.y=1
    self.w=10
    self.h=2
    self.hide=false

    self.val=30
    self.maxval=100
    self.fcolor=0x00FF00
    self.bcolor=0x0
end

function ProgressBar:update(gpu)
    local persent=self.val/self.maxval
    local colp=persent*self.w

    gpu:pushbg(self.fcolor)
    for j=self.x,self.x+colp-1,1 do
        for i=self.y,self.y+self.h,1 do
            gpu:set(i,j," ")
        end
    end

    gpu:pushbg(self.bcolor)
    for j=self.x+colp,self.x+self.w,1 do
        for i=self.y,self.y+self.h,1 do
            gpu:set(i,j," ")
        end
    end

    gpu:popbg()
    gpu:popbg()
end