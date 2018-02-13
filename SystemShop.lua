require("libevent")
require("util")
local component = require("component")
local sides = require("sides")

-- System buy from player

-- Auto configure
local modem = proxy("modem")
local trans = proxy("transposer")
local redgate = proxy("redstone")

-- Variables

-- Functions

local function init()
    if(modem==nil or trans==nil or redgate==nil) then
        error("Failed on checking devices.")
    end

    modem.open(10011)

    redgate.setOutput(sides.east,0) -- open gate
end

local function uninit()
    redgate.setOutput(sides.east,15) -- close gate on stop
end

local function main()
    init()
    while true do 
        print("Item Price:")
        print("Log (yuan mu) : $0.5")
        print("Other : $0.1")

        local e=WaitMultipleEvent("bioReader","modem_message","interrupted")
        if(e.event=="bioReader") then
            redgate.setOutput(sides.east,15) -- close gate
            local sum=0
            local x=trans.getAllStacks(sides.south) -- check item
            while true do
                local y=x()
                if(y==nil) then 
                    break
                end
                if(y.size~=nil) then
                    if(y.name=="minecraft:log") then
                        sum=sum+y.size*0.5
                    else
                        sum=sum+y.size*0.1
                    end
                end
            end

            print("Total Price: " .. sum)

            -- Transfer item
            print("Transfering items ... ")
            while (trans.transferItem(sides.south,sides.down)) do 
            end
            print("Done")

            redgate.setOutput(sides.east,0) -- open gate
        else
            print("Received ctrl+c signal.")
            break
        end
    end
    uninit()
end

print("SystemShop Start")
main()
print("SystemShop Stopped")