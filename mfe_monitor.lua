-- Energy monitor
-- Does not require any external library.
-- Designed to run on Tier 1 CPU with Tier 1 RAM
local function gettimestr(s)
    local ans=''
    if(s<60) then
        return '' .. s .. "s"
    elseif(s<3600) then
        return '' .. math.ceil(s/60) .. "m," .. gettimestr(s%60)
    else
        return '>1h'
    end
end
local function xnum(x)
    return math.ceil(x*100)/100
end
local component=require("component")
local sides=require("sides")
local serialization=require("serialization")
local shell=require("shell")
local args=shell.parse(...)
local intv=1
if(args[1]~=nil) then intv=tonumber(args[1]) end
print("Interval:",intv)
local m=component.proxy(component.list("ic2_te_mfe")())
local net=component.list("modem")()
local netok=false
if(net~=nil) then
    print("netcard modem found.")
    net=component.proxy(net)
    netok=true
end
local function broad(tb)
    if(netok) then
        net.broadcast(996,serialization.serialize(tb))
    end
end
local cap=m.getCapacity()
local post=m.getEnergy()
print("Monitor started. Press Ctrl+Alt+C to stop it.")
while(true) do
    os.sleep(intv)
    local now=m.getEnergy()
    io.write("[" .. xnum(now/cap) .. "%] ")
    if(now-post>=0) then
        print("Created " .. xnum(now-post)  .. "EU. +" .. xnum((now-post)/intv/20) .. "/t. Full in " .. gettimestr(math.ceil((cap-now)/(now-post))))
        broad({
            ["eu"]= xnum(now-post),
            ["per"]=xnum((now-post)/intv/20),
            ["time"]=math.ceil((cap-now)/(now-post))
        })
    else
        print("Used " .. xnum(post-now) .. "EU. -" .. xnum((post-now)/intv/20) .. "/t. Run out in " .. gettimestr(math.ceil(now/(post-now))))
        broad({
            ["eu"]= xnum(now-post),
            ["per"]=xnum((now-post)/intv/20),
            ["time"]=math.ceil(now/(post-now))
        })
    end
    post=now
end