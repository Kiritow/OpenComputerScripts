-- Storage Center and Auto Crafting
-- Requires:
--      Computer with wireless network card
--      Robot with craft upgrade and inventory upgrade, wireless network card
--      Transposer

require("libevent")
require("util")
local component=require("component")

local modem=component.list("modem")
if(modem==nil) then
    error("Modem is required")
else
    modem=component.proxy("modem")
end

-- Config
local craft_trans=proxy("transposer","")
local craft_trans_side_in=sides.west
local craft_trans_side_out=sides.east
local craft_trans_side_interface=sides.south

-- End of Config

local craft_db={}

local function readCraftTable()
    local tb={}
    tb.input={}
    for i=1,3,1 do
        for j=1,3,1 do
            local p=craft_trans.getStackInSlot(sides.up,(i-1)*9+j)
            if(p~=nil) then
                table.insert(tb.input,{
                    ["i"]=i,
                    ["j"]=j,
                    ["name"]=p.name,
                    ["size"]=p.size})
            end
        end
    end

    local xp=craft_trans.getStackInSlot(sides.up,2*9+5)
    if(p~=nil) then
        tb.output=xp.name
    else
        return false,"No craft target found. Invalid Plan."
    end

    return true,tb
end

local function netRobotCraft()
    if(not modem.isOpen(2801)) then
        if(not modem.open(2801)) then
            return false,"Port can't be opened."
        end
    end

    local bus=CreateEventBus()
    bus:listen("modem_message")
    local craft_started=false
    modem.broadcast(2802,"robotCraft")
    local e=bus:next(3) -- Wait for 3 second
    if(e~=nil) then
        if(e.data[1]=="craft_started") then
            craft_started=true
            break
        end
    end

    if(not craft_started) then
        return false,"Cannot tell robot to start craft"
    end

    local e=bus:next()
    if(e.data[1]~="craft_finished") then
        return false,"Craft Failed"
    end
end

local function doCraftOnce(craft_table)
    for k,v in pairs(craft_table) do
        transferFromBaseToInterface(v.name,v.size,(v.i-1)*9+j)
    end
    local ret,msg=netRobotCraft()
    if(not ret) then
        return false,"Craft Failed. " .. msg
    end
end

local function craftOnce(name)
    for k,v in pairs(craft_tb) do
        if(v.output==name) then
            doCraftOnce(v.input)
            return
        end
    end
    error("Craft table not found")
end
