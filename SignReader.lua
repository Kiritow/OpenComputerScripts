require("class")
local sides=require("sides")

SignReader=class("SignReader")

function SignReader:ctor(sign)
    self.s=sign
end

function SignReader:countSigns()
    local cnt=0
    if(self:get(sides.north) ~= nil) then cnt=cnt+1 end
    if(self:get(sides.south) ~= nil) then cnt=cnt+1 end
    if(self:get(sides.east) ~= nil) then cnt=cnt+1 end
    if(self:get(sides.west) ~= nil) then cnt=cnt+1 end
    if(self:get(sides.up) ~= nil) then cnt=cnt+1 end
    if(self:get(sides.down) ~= nil) then cnt=cnt+1 end
    return cnt
end

function SignReader:getFirstSignSide()
    if(self:get(sides.north)~=nil) then return sides.north end
    if(self:get(sides.south)~=nil) then return sides.south end
    if(self:get(sides.east)~=nil) then return sides.east end
    if(self:get(sides.west)~=nil) then return sides.west end
    if(self:get(sides.up)~=nil) then return sides.up end
    if(self:get(sides.down)~=nil) then return sides.down end
    return -1
end

function SignReader:get(side)
    if(side == nil) then -- Try Smart Choice
        if(self:countSigns() == 1) then
            return self.s.getValue(self:getFirstSignSide())
        else
            return nil -- Cannot choose
        end
    else
        return self.s.getValue(side)
    end
end

function SignReader:set(val,side)
    if(side == nil) then -- Try Smart Choice
        if(self:countSigns() == 1) then
            return self.s.setValue(self:getFirstSignSide(),val)
        else
            return nil -- Cannot choose
        end
    else
        return self.s.setValue(side,val)
    end
end
