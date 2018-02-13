local component = require("component")
local sides = require("sides")
local serialization = require("serialization")

local function getSum(device)
    local unit=0
    local cnt=0
    local allunit=0

    local sz=device.getInventorySize(sides.north)

    -- faster enum
    local x=device.getAllStacks(sides.north)
    while true do
        local y=x()
        if(y==nil) then 
            break
        end
        if(y.size~=nil) then
            cnt=cnt+y.size
            unit=unit+1
        end
    end

    allunit=sz

    sz=device.getInventorySize(sides.south)
    
    -- faster enum
    x=device.getAllStacks(sides.south)
    while true do
        local y=x()
        if(y==nil) then 
            break 
        end
        if(y.size~=nil) then
            cnt=cnt+y.size
            unit=unit+1
        end
    end

    allunit=allunit+sz

    return cnt,unit,allunit
end

while true do
    local lst=component.list("inventory_controller")
    
    local sumunit=0
    local totalunit=0
    local sum=0
    local idx=1
    while true do
        local addr=lst()
        if(addr==nil) then 
            break
        end
        print("Counting " .. idx)
        local val,unit,allunit=getSum(component.proxy(addr))
        print("ChestGroup " .. idx .. " has " .. val .. " items")
        sum=sum+val
        sumunit=sumunit+unit
        totalunit=totalunit+allunit
        idx=idx+1
    end

    local str="Total " .. sum .. " items of " .. totalunit*64 .. " (" .. sum/totalunit/64*100 .. "%). " .. 
    sumunit .. " of " .. totalunit .. " units used (" .. sumunit/totalunit*100 .. "%) "
    
    print("Total " .. sum .. " items")

    local tb={}
    tb.item=sum
    tb.maxitem=totalunit*64
    tb.unit=sumunit
    tb.maxunit=totalunit

    print(str)

    component.modem.broadcast(10010,str)
    component.modem.broadcast(10011,serialization.serialize(tb))

    print("Waiting for next loop...")
    os.sleep(5)
end
