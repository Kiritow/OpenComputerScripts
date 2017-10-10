require("class")

Vector=class("Vector")

function Vector:_reset()
self.sz=0
self.bus={}
end

function Vector:ctor(t)
self:_reset()
if((t ~= nil) and (type(t) == "table")) then
for k,v in pairs(t) do
local x={}
x.first=k
x.second=v
self:push_back(x)
end --for
end --if
end --func

function Vector:empty()
return self.sz==0
end

function Vector:push_back(val)
self.bus[self.sz]=val
self.sz=self.sz+1
end

function Vector:pop_back()
if(self:empty()) then return nil
else
local val=self.bus[self.sz-1]
self.bus[self.sz-1]=nil
self.sz=self.sz-1
return val
end
end

function Vector:front()
if(self:empty()) then return nil
else return self.bus[0]
end
end

function Vector:back()
if(self:empty()) then return nil
else return self.bus[self.sz-1]
end
end

function Vector:clear()
self:_reset()
end

function Vector:at(index)
if(type(index) ~= "number") then return nil
elseif(self:empty()) then return nil
elseif(index<0) then return nil
elseif(index>=self.sz) then return nil
else return self.bus[index]
end
end

function Vector:size()
return self.sz
end

function Vector:insert_after(index,val)
if(type(index) ~= "number") then return nil
elseif(index>=self.sz) then return nil
elseif(index<-1) then return nil
else
for i=self.sz-1,index+1,-1 do
self.bus[i+1]=self.bus[i]
end
self.bus[index+1]=val
self.sz=self.sz+1
end
end

function Vector:erase(index)
if(type(index) ~= "number") then return nil
elseif(index>=self.sz) then return nil
elseif(index<0) then return nil
else
for i=index+1,self.sz-1,1 do
self.bus[i-1]=self.bus[i]
end
self.sz=self.sz-1
end
end
