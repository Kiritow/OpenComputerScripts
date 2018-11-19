-- Smart Storage
-- Author: Kiritow

local component=require('component')
local sides=require('sides')
local term=require('term')
local shell=require('shell')
require('libevent')

local version_tag="Smart Storage v0.5.1"

print(version_tag)
print("Checking hardware...")
local modem=component.modem
local gpu=component.gpu
if(not modem or not gpu) then
    print("This program need GPU and Modem Component to run.")
    return
end
print("Reading config...")

print("Checking robot...")
local robotAddr=''
modem.open(1001)
-- Computer --1000--> robot, robot --1001--> Computer
modem.broadcast(1000,"find_crafting_robot")
while true do 
    local e=WaitEvent("modem_message")
    if(e.port==1001 and e.data[1]=="crafting_robot_response") then 
        print("Found crafting robot: " .. e.senderAddress)
        robotAddr=e.senderAddress
        break
    end
end
print("Prepare to start...")

local function status(msg)
    local w,h=gpu.getResolution()
    gpu.fill(1,h,w,1,' ')
    gpu.set(1,h,"Status: " .. msg)
end

local function do_reform()
    local total=0
    local all_sides={sides.north,sides.south,sides.west,sides.east}
    for addr in pairs(component.list("transposer")) do
        local this_trans=component.proxy(addr)
        for idx,this_side in ipairs(all_sides) do
            if(this_trans.getInventoryName(this_side)) then
                while true do
                    local done=this_trans.transferItem(sides.up,this_side)
                    if(done<1) then break end
                    total=total+this_trans.transferItem(sides.up,this_side)
                end
                status("[Working] " .. total .. " items moved.")
            end
        end
    end
end

local function getItemXID(name,label)
    return name .. ';' .. label
end

local function full_scan()
    local all_sides = {sides.up,sides.north,sides.south,sides.west,sides.east}
    local result={}
    local slot_used=0
    local slot_total=0

    local count_transposer=0
    local count_box=0

    for addr in pairs(component.list("transposer")) do
        local this_trans=component.proxy(addr)
        for idx,this_side in ipairs(all_sides) do
            local this_box=this_trans.getAllStacks(this_side)
            if(this_box~=nil) then
                local this_slot_id=0
                while true do
                    local this_slot=this_box()
                    if(this_slot==nil) then break end
                    this_slot_id=this_slot_id+1
                    slot_total=slot_total+1

                    if(this_slot.size) then
                        slot_used=slot_used+1
                        local xid=getItemXID(this_slot.name,this_slot.label)
                        if(not result[xid]) then
                            result[xid]={
                                name=this_slot.name,
                                label=this_slot.label,
                                total=0,
                                position={}
                            }
                        end
                        table.insert(result[xid].position,{addr=addr,side=this_side,slot=this_slot_id,size=this_slot.size})
                        result[xid].total=result[xid].total+this_slot.size
                    end
                end
                count_box=count_box+1
                status("[Working] Scanned transposer: " .. count_transposer .. " box: " .. count_box)
            end
        end

        count_transposer=count_transposer+1
        status("[Working] Scanned transposer: " .. count_transposer .. " box: " .. count_box)
    end

    status("[Done] Scanned transposer: " .. count_transposer .. " box: " .. count_box)

    result["slot_used"]=slot_used
    result["slot_total"]=slot_total

    return result
end

local function GetDisplayTable(result)
    local keys={}
    for k,v in pairs(result) do
        table.insert(keys,k)
    end
    table.sort(keys)
    return keys
end

--[[ Display Design
1: Smart Storage (version info etc.)
2: ------------ (window title here) ------------
3 ~ h-3: Content displayed here
h-2: ---------- (page info here) ---------------
h-1: Buttons
h: Status bar
--]]

local function display_single(tb_data,tb_display,which_one,display_at)
    local w,h=gpu.getResolution()
    gpu.fill(1,display_at,w,1,' ')
    local this_table=tb_data[tb_display[which_one]]
    gpu.set(1,display_at,this_table.name .. " -- " .. this_table.label .. " (" .. this_table.total .. ")")
end

local function display(tb_data,tb_display,begin_at)
    local w,h=gpu.getResolution()
    gpu.fill(1,1,w,h-1,' ') -- Status bar is not cleared
    gpu.set(1,1,version_tag)
    gpu.fill(1,2,w,1,'-')
    gpu.fill(1,h-2,w,1,'-')
    gpu.set(1,h-1,"<Refresh> <Reform>")

    local count_shown=0
    for i=begin_at,#tb_display,1 do
        count_shown=count_shown+1
        local this_table=tb_data[tb_display[i]]
        gpu.set(1,i-begin_at+3,this_table.name .. " -- " .. this_table.label .. " (" .. this_table.total .. ")")
        if(i-begin_at+3>=h-3) then break end
    end

    gpu.set(4,2," Viewing " .. begin_at .. "~" .. begin_at+count_shown .. " of " .. #tb_display .. " ")
    gpu.set(4,h-2," Space used: " .. math.floor(tb_data.slot_used/tb_data.slot_total*1000)/10 .. "% (" .. tb_data.slot_used .. "/" .. tb_data.slot_total ..") ")
end

term.clear()
print("Smart Storage System Initializing...")
status("Scanning...")
local result=full_scan()
local tb_display=GetDisplayTable(result)
local begin_at=1

local need_refresh=true
while true do
    if(need_refresh) then
        display(result,tb_display,begin_at)
        need_refresh=false
    end

    local e=WaitMultipleEvent("interrupted","scroll","touch")

    if(e.event=="interrupted") then
        break
    elseif(e.event=="scroll") then
        -- Scroll Down = -1. Scroll Up = 1
        if(e.direction<0) then
            if(begin_at<#tb_display) then
                begin_at=begin_at+1
                need_refresh=true
            end
        else
            if(begin_at>1) then
                begin_at=begin_at-1
                need_refresh=true
            end
        end
    elseif(e.event=='touch') then
        local w,h=gpu.getResolution()
        if(e.y==h-1) then
            if(e.x<=string.len("<Refresh>")) then
                status("Rescanning...")
                result=full_scan()
                tb_display=GetDisplayTable(result)
                begin_at=1

                need_refresh=true
            elseif(e.x<=string.len("<Refresh> <Reform>")) then
                status("Reforming...")
                do_reform()

                result=full_scan()
                tb_display=GetDisplayTable(result)
                begin_at=1

                need_refresh=true
            end
        elseif(e.y>=3 and e.y<=h-3) then
            if(begin_at+e.y-3<=#tb_display) then
                need_refresh=true

                local this_table=result[tb_display[begin_at+e.y-3]]
                term.setCursor(1,h-1)
                term.clearLine()
                io.write('[' .. this_table.name .. " -- " .. this_table.label .. "]. How many? (" .. this_table.total .. "): ")
                local n=io.read('n')
                if(not n or n>this_table.total) then 
                    status("Invalid input.")
                else
                    status("Transfer begins.")
                    local fetched=0
                    for idx,this_info in ipairs(this_table.position) do
                        local this_trans=component.proxy(this_info.addr)
                        local need=0
                        if(this_info.size>n-fetched) then
                            need=n-fetched
                        else
                            need=this_info.size
                        end
                        local done=this_trans.transferItem(this_info.side,sides.down,need,this_info.slot)
                        fetched=fetched+done
                        this_info.size=this_info.size-done
                        this_table.total=this_table.total-done
                        if(fetched>=n) then break end
                        status("" .. fetched .. " of " .. n .. " items transferred.")
                    end

                    -- Update storage info
                    local idx=1
                    while(idx<=#this_table.position) do
                        if(this_table.position[idx].size<=0) then
                            table.remove(this_table.position,idx)
                            result.slot_used=result.slot_used-1
                        else
                            idx=idx+1
                        end
                    end
                    if(this_table.total<1) then
                        result[tb_display[begin_at+e.y-3]]=nil -- Remove this type
                        table.remove(tb_display,begin_at+e.y-3)

                        if(begin_at>1) then
                            begin_at=begin_at-1
                        end
                    end

                    status("" .. n .. " items transferred")
                end
            end
        end
    end
end

term.clear()