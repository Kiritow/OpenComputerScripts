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
local gate_allow = true

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

    local bus=CreateEventBus()
    bus:listen("bioReader")
    bus:listen("modem_message")
    bus:listen("interrupted")

    while true do 
        print("Item Price:")
        print("Log (yuan mu) : $0.5")
        print("Other : $0.1")

        local e=bus:next()
        if(e.event=="bioReader") then
            if(not gate_allow) then
                print("Gate is closed. Cannot sell items at present.")
            else
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

                while true do
                    -- Transfer item
                    print("Transfering items ... ")
                    while (trans.transferItem(sides.south,sides.down)) do 
                    end

                    -- check if left.
                    x=trans.getAllStacks(sides.south)
                    local left=false
                    while true do 
                        local y=x()
                        if(y==nil) then 
                            break
                        end
                        if(y.size~=nil) then
                            left=true
                            break
                        end
                    end
                    if(left) then
                        print("Transfer busy. Waiting...")
                        os.sleep(5)
                    else
                        break
                    end
                end
                print("Done")

                redgate.setOutput(sides.east,0) -- open gate
            end
        elseif(e.event=="modem_message") then
            local tb=unserialize(e.data[1])
            local rate=tb.unit/tb.maxunit*100
            if(rate>60) then 
                print("DestroyFactory Busy. Gate is closed for security.")
                gate_allow=false
            else
                gate_allow=true
            end
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