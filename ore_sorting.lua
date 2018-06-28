-- Ore sorting
-- Level Up! mod gives mined ore NBT tags.
-- We use Mekanism to process non-NBT ores,
-- and IC2 for NBT ores.
local component=require("component")
local trans=component.proxy(component.list("transposer")()) or
    component.proxy(component.list("inventory_controller"))
local sides=require("sides")
while true do
    print("Scanning...")
    local max=trans.getInventorySize(sides.up)
    for i=1,max,1 do
        local tb=trans.getStackInSlot(sides.up,i)
        if(tb~=nil) then
            if(tb.hasTag) then
                print("tag " .. tb.size)
                trans.transferItem(sides.up,sides.west,tb.size,i)
            else
                print("no tag " .. tb.size)
                trans.transferItem(sides.up,sides.north,tb.size,i)
            end
        end
    end
    print("Next loop in 30 seconds...")
    os.sleep(30)
end
