-- Smart Storage Robot
-- Author: Kiritow

local component=require('component')
local sides=require('sides')
local serialization=require('serialization')
local robot=require('robot')

require('libevent')

local version_tag="Smart Storage Robot v0.1"

print(version_tag)
print("Checking hardware...")
local modem=component.modem
local crafting=component.crafting
local controller=component.inventory_controller
if(not modem or not crafting or not controller or robot.inventorySize()<16) then 
    print("This program requires Modem, Crafting upgrade, Inventory Controller upgrade and at least a 16-slot inventory to run.")
    return 
end
print("Reading config...")

print("Waiting for Smart Storage System... (Ctrl+C to stop)")
local sysAddr=''
modem.open(1000)
while true do
    local e=WaitMultipleEvent("modem_message","interrupted")
    if(e.event=="interrupted") then
        print("Cancelled by user.")
        modem.close(1000)
        return 
    elseif(e.event=="modem_message" and e.port==1000 and e.data[1]=="find_crafting_robot") then
        print("System request received.")
        sysAddr=e.senderAddress
        modem.send(sysAddr,1001,"crafting_robot_response")
        print("Response sent.")
        break
    end
end
print("Smart Storage System set to " .. sysAddr)
while true do
    print("Waiting for requests... (Ctrl+C to stop)")
    local e=WaitMultipleEvent("modem_message","interrupted")
    if(e.event=="interrupted") then
        print("Receive stop signal") 
        break
    elseif(e.event=="modem_message" and e.port==1000) then
        if(e.data[1]=="do_craft") then
            print("[Pending] Sending response...")
            modem.send(sysAddr,1001,"craft_started")
            print("[Working] Start craft task...")
            local from_slot={1,2,3,10,11,12,19,20,21}
            local to_slot={1,2,3,5,6,7,9,10,11}
            print("[Working] Moving resource...")
            for i=1,9,1 do 
                robot.select(to_slot[i])
                controller.suckFromSlot(sides.front,from_slot[i])
            end
            print("[Working] Crafting...")
            robot.select(4)
            local result=crafting.craft()
            print("[Working] Craft result: ",result)
            print("[Working] Cleaning inventory...")
            for i=1,16,1 do
                robot.select(i)
                robot.drop()
            end
            modem.send(sysAddr,1001,"craft_done",result)
            print("[Done] Task craft finished.")
        end
    end
end

print("Closing ports...")
modem.close(1000)