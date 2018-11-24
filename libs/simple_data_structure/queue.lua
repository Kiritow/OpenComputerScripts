require("class")

Queue = class("Queue")

function Queue:reset()
    self.size = 0
    self.bus = {}
    self.headindex = -1
    self.tailindex = -1
end

function Queue:ctor()
    self:reset()
end

function Queue:empty()
    return self.size == 0
end

function Queue:push(val)
    if (self:empty()) then
        self.headindex = 0
        self.tailindex = 0
        self.size = 1
        self.bus[0] = val
    else
        self.tailindex = self.tailindex + 1
        self.bus[self.tailindex] = val
        self.size = self.size + 1
    end
end

function Queue:top()
    if(self:empty()) then
        return nil
    else
        return self.bus[self.headindex]
    end
end

function Queue:pop()
    if (self:empty()) then
        return nil
    else
        ret = self.bus[self.headindex]
        self.bus[self.headindex] = nil
        self.size = self.size - 1
        if (self:empty()) then
            self:reset()
        else
            self.headindex = self.headindex + 1
        end
        return ret
    end
end
