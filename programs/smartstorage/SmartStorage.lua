-- Smart Storage
-- Author: Kiritow

local component=require('component')
local sides=require('sides')
local term=require('term')
local shell=require('shell')
local serialization=require('serialization')

require('libevent')

local version_tag="Smart Storage v0.6.3-dbg"
local args,options=shell.parse(...)

print(version_tag)

if(options["version"]) then
    -- Version tag has been displayed.
    return
elseif(options["help"] or options["h"]) then
    print("Smart Storage Manual")
    print("-- To be continued...")

    return
end

print("Checking hardware...")
local modem=component.modem
local gpu=component.gpu
if(not modem or not gpu) then
    print("This program need GPU and Modem Component to run.")
    return
end
print("Reading config...")
print("Please input IO transposer address:")
local io_trans_addr=io.read()
print("Sides value: up:" .. sides.up .. " down:" .. sides.down .. " north:" .. sides.north .. " south:" .. sides.south .. " west:" .. sides.west .. " east:" .. sides.east)
print("Please input IO transposer input side:")
local io_trans_input_side=io.read("n")
print("Please input IO transposer output side:")
local io_trans_output_side=io.read("n")
print("Please input IO transposer buffer side:")
local io_trans_buffer_side=io.read("n")

print("Checking robot...")
local robotAddr=''
modem.open(1001)
-- Computer --1000--> robot, robot --1001--> Computer
modem.broadcast(1000,"find_crafting_robot")
while true do 
    local e=WaitEvent(5,"modem_message")
    if(e==nil) then 
        print("Unable to find robot in 5 seconds. Failed to start")
        modem.close(1001)
        return 
    elseif(e.port==1001 and e.data[1]=="crafting_robot_response") then 
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

    local temp_transposers=component.list("transposer")
    temp_transposers[io_trans_addr]=nil

    for addr in pairs(temp_transposers) do
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

    local temp_transposers=component.list("transposer")
    temp_transposers[io_trans_addr]=nil

    for addr in pairs(temp_transposers) do
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
        if(k~="slot_used" and k~="slot_total") then 
            table.insert(keys,k)
        end
    end
    table.sort(keys)
    return keys
end

local function GetDisplayTableFiltered(result,filter)
    local keys={}
    for k,v in pairs(result) do 
        if(k~="slot_used" and k~="slot_total" and string.find(k,filter)~=nil) then
            table.insert(keys,k)
        end
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

local function display(tb_data,tb_display,tb_craft,begin_at,filter)
    local w,h=gpu.getResolution()
    gpu.fill(1,1,w,h-1,' ') -- Status bar is not cleared
    gpu.set(1,1,version_tag)
    gpu.fill(1,2,w,1,'-')
    gpu.fill(1,h-2,w,1,'-')
    gpu.set(1,h-1,"<Refresh> <Reform> <Set Filter> <Clear Filter> <Read recipe> <Debug>")

    local count_shown=0
    for i=begin_at,#tb_display,1 do
        local this_table=tb_data[tb_display[i]]

        local old_f=nil
        local old_b=nil

        if(filter~=nil and string.len(filter)>0 and string.find(this_table.name,filter)~=nil) then
            old_f=gpu.setForeground(0xFFFF00)
        end
        if(tb_craft[tb_display[i]]~=nil) then
            old_b=gpu.setBackground(0x0000FF)
        end
        
        gpu.set(1,i-begin_at+3,this_table.name .. " -- " .. this_table.label .. " (" .. this_table.total .. ")")

        if(old_f) then gpu.setForeground(old_f) end
        if(old_b) then gpu.setBackground(old_b) end

        count_shown=count_shown+1
        if(i-begin_at+3>=h-3) then break end
    end

    if(filter~=nil and string.len(filter)>0) then
        gpu.set(4,2," Viewing " .. begin_at .. "~" .. begin_at+count_shown .. " of " .. #tb_display .. ". Filter: " .. filter)
    else
        gpu.set(4,2," Viewing " .. begin_at .. "~" .. begin_at+count_shown .. " of " .. #tb_display .. ". ")
    end
    gpu.set(4,h-2," Space used: " .. math.floor(tb_data.slot_used/tb_data.slot_total*1000)/10 .. "% (" .. tb_data.slot_used .. "/" .. tb_data.slot_total ..") ")
end

local function SystemGetItem(tb_data,tb_display,request_key,request_amount)
    local fetched=0
    local this_table=tb_data[request_key]
    for idx,this_info in ipairs(this_table.position) do
        local this_trans=component.proxy(this_info.addr)
        local need=0
        if(this_info.size>request_amount-fetched) then
            need=request_amount-fetched
        else
            need=this_info.size
        end
        local done=this_trans.transferItem(this_info.side,sides.down,need,this_info.slot)
        fetched=fetched+done
        this_info.size=this_info.size-done
        this_table.total=this_table.total-done
        if(fetched>=request_amount) then break end
        status("[Working] " .. fetched .. " of " .. request_amount .. " items transferred.")
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
        tb_data[request_key]=nil -- Remove this type
        for idx,value in ipairs(tb_display) do
            if(tb_display[idx]==request_key) then
                table.remove(tb_display,idx)
                break 
            end
        end

        if(begin_at>1) then
            begin_at=begin_at-1
        end
    end

    status("[Done] " .. fetched .. " of " .. request_amount .. " items transferred") -- Sometimes (ex: output box is full) not all items can be transferred.

    return fetched
end

term.clear()
print("Smart Storage System Starting...")
status("Scanning...")
-- These variable should be local. Here is just for debug purpose.
craft_table={}
result=full_scan()
tb_display=GetDisplayTable(result)
begin_at=1
item_filter=''

local need_refresh=true

while true do
    if(need_refresh) then
        display(result,tb_display,craft_table,begin_at,item_filter)
        need_refresh=false
    end

    local e=WaitMultipleEvent("interrupted","scroll","touch","key_down")

    if(e.event=="interrupted") then
        break
    elseif(e.event=="key_down") then
        local w,h=gpu.getResolution()
        if(e.code==201) then -- PageUp
            if(begin_at>1) then
                begin_at=begin_at-(h-5)
                if(begin_at<1) then begin_at=1 end
                need_refresh=true
            end
        elseif(e.code==209) then -- PageDown
            if(begin_at+h-5<#tb_display) then 
                begin_at=begin_at+h-5
                need_refresh=true
            end
        end
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
            elseif(e.x<=string.len("<Refresh> <Reform> <Set Filter>")) then
                term.setCursor(1,h-1)
                term.clearLine()
                io.write("Filter: ")
                item_filter=io.read()

                if(item_filter~=nil and string.len(item_filter)>0) then
                    tb_display=GetDisplayTableFiltered(result,item_filter)
                    begin_at=1
                end

                need_refresh=true
            elseif(e.x<=string.len("<Refresh> <Reform> <Set Filter> <Clear Filter>")) then
                if(item_filter~=nil and string.len(item_filter)>0) then
                    item_filter=''

                    tb_display=GetDisplayTable(result)
                    begin_at=1

                    need_refresh=true
                end
            elseif(e.x<=string.len("<Refresh> <Reform> <Set Filter> <Clear Filter> <Read recipe>")) then
                status("Reading recipe from buffer chest...")
                --[[ Example recipe table
                    newRecipe={
                        to={
                            id= "Item XID of chest",
                            size=1
                        },
                        from={
                            { -- slot 1
                                id= " Item XID of wood ",
                                size=1
                            }, 
                            ... repeat 3 times, (slot 2~4)
                            nil, -- empty in slot 5
                            { -- slot 6
                                id= " Item XID of wood ",
                                size=1
                            },
                            ... repeat 3 times, (slot 6~9)
                        }
                    }
                --]]
                local newRecipe={
                    from={},
                    to={}
                }

                local io_trans=component.proxy(io_trans_addr)
                local temp=io_trans.getStackInSlot(io_trans_buffer_side,14)
                if(temp==nil or temp.size==nil) then
                    status("Recipe invalid: no craft result")
                else
                    newRecipe.to.id=getItemXID(temp.name,temp.label)
                    newRecipe.to.size=temp.size
                    
                    local from_slots={1,2,3,10,11,12,19,20,21}
                    for idx,from_slot in ipairs(from_slots) do
                        temp=io_trans.getStackInSlot(io_trans_buffer_side,from_slot)
                        if(temp~=nil and temp.size~=nil) then
                            newRecipe.from[idx]={
                                id=getItemXID(temp.name,temp.label),
                                size=temp.size
                            }
                        end
                    end

                    if(not craft_table[newRecipe.to.id]) then
                        craft_table[newRecipe.to.id]={}
                    end
                    table.insert(craft_table[newRecipe.to.id],{size=newRecipe.to.size,from=newRecipe.from})
                    status("New recipe added")

                    need_refresh=true 
                end
            elseif(e.x<=string.len("<Refresh> <Reform> <Set Filter> <Clear Filter> <Read recipe> <Debug>")) then
                term.setCursor(1,h-1)
                term.clearLine()
                io.write("Lua: ")
                local str=io.read()
                if(str) then
                    local f,err=load(str,"UserChunk","t",_ENV)
                    if(f==nil) then 
                        status("Invalid Debug: " .. err)
                    else
                        local ok,err=pcall(f)
                        if(not ok) then 
                            status("Debug Failed: " .. err)
                        end
                    end
                    need_refresh=true
                end
            end
        elseif(e.y>=3 and e.y<=h-3) then
            if(begin_at+e.y-3<=#tb_display) then
                if(e.button==0) then -- Left click
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

                        SystemGetItem(result,tb_display,tb_display[begin_at+e.y-3],n)
                    end
                elseif(e.button==1) then -- Right click
                    if(craft_table[tb_display[begin_at+e.y-3]]==nil) then
                        status("This item can't be crafted.")
                    else
                        need_refresh=true
                        local this_table=result[tb_display[begin_at+e.y-3]]
                        local this_recipe_list=craft_table[tb_display[begin_at+e.y-3]]
                        local resolved_recipe_id=nil

                        status("Calculating crafting need...")
                        for idx,this_recipe in ipairs(this_recipe_list) do 
                            status("[Working] Checking recipe " .. idx .. "...")
                            local temp_sum={}
                            for idx,this_from in pairs(this_recipe.from) do
                                if(not temp_sum[this_from.id]) then
                                    temp_sum[this_from.id]=0
                                end
                                temp_sum[this_from.id]=temp_sum[this_from.id]+this_from.size
                            end
                            local available=true
                            for this_id,this_amount in pairs(temp_sum) do
                                status("[Checking] ID=" .. this_id)
                                if(result[this_id].total<this_amount) then
                                    available=false
                                    break
                                end
                            end
                            if(available) then 
                                resolved_recipe_id=idx
                                break
                            end
                        end

                        if(not resolved_recipe_id) then
                            status("Unable to craft. Not enough ingredients.")
                        else
                            status("[Checked] Following recipe " .. resolved_recipe_id)
                            local follow_recipe=this_recipe_list[resolved_recipe_id]

                            local target_slot={1,2,3,10,11,12,19,20,21}
                            local flag_done=true

                            local io_trans=component.proxy(io_trans_addr)

                            for idx,this_slot in pairs(follow_recipe.from) do 
                                local ans=SystemGetItem(result,tb_display,this_slot.id,this_slot.size)
                                if(ans~=this_slot.size) then 
                                    flag_done=false
                                    break
                                end
                            end

                            if(not flag_done) then
                                status("Unable to craft. Failed to fetch enough item.")
                            else
                                status("[Working] Clearing buffer chest...")
                                while io_trans.transferItem(io_trans_buffer_side,io_trans_output_side)>0 do end
                                status("[Working] Moving resource to buffer chest...")
                                for i=1,9,1 do 
                                    if(follow_recipe.from[i]) then
                                        status("[Working] Gathering item for slot " .. i .. "...")
                                        local which_slot=0
                                        while true do
                                            local j=0
                                            local this_slots=io_trans.getAllStacks(io_trans_output_side)
                                            while true do
                                                local this_info=this_slots()
                                                if(this_info==nil) then break end
                                                j=j+1
                                                if(this_info~=nil and this_info.size~=nil and 
                                                    (getItemXID(this_info.name,this_info.label)==follow_recipe.from[i].id) and
                                                    (this_info.size>=follow_recipe.from[i].size)
                                                ) then
                                                    which_slot=j
                                                    break
                                                end
                                            end

                                            if(which_slot>0) then break end
                                            status("[Working] Waiting item for slot " .. i .. "...")
                                        end
                                        io_trans.transferItem(io_trans_output_side,io_trans_buffer_side,follow_recipe.from[i].size,which_slot,target_slot[i])
                                    end
                                end

                                status("[Pending] Waiting for robot response...")
                                modem.send(robotAddr,1000,"do_craft")
                                local robot_ok=true
                                while true do 
                                    local e=WaitEvent(5,"modem_message")
                                    if(e==nil) then
                                        status("Unable to craft. Robot no response.")
                                        robot_ok=false
                                        break
                                    elseif(e.event=="modem_message" and e.port==1001 and e.data[1]=="craft_started") then
                                        break 
                                    end
                                end

                                if(robot_ok) then
                                    status("[Pending] Robot is crafting... (Ctrl+C to stop)")
                                    local craft_done=false
                                    local craft_ok=false
                                    while true do
                                        local e=WaitMultipleEvent("modem_message","interrupted")
                                        if(e.event=="interrupted") then 
                                            status("Craft process is cancelled by user.")
                                            break
                                        elseif(e.event=="modem_message" and e.port==1001 and e.data[1]=="craft_done") then
                                            status("[Working] Robot crafting finished.")
                                            craft_ok=e.data[2]

                                            craft_done=true
                                            break
                                        end
                                    end

                                    if(craft_done) then
                                        status("[Working] Moving items to output chest...")
                                        while io_trans.transferItem(io_trans_buffer_side,io_trans_output_side)>0 do end
                                        if(craft_ok) then
                                            status("[Done] Item crafted successfully.")
                                        else
                                            status("[Done] Item failed to craft.")
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

term.clear()
print("Smart Storage System Stopping...")
print("Closing modem ports...")
modem.close(1001)
