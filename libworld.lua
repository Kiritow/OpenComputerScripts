-- LibWorld - Copy and paste world area, store in digital type.
-- Author: Github/Kiritow

local component=require("component")

-- Copy an area. returns a table contains area info.
-- Can be serialized and stored in files.
function CopyArea(ax,ay,az,bx,by,bz)
    local debugcard=component.debug
    if(debugcard==nil) then
        error("This program require debug card.")
    end

    local box={}
    if(ax>bx) then ax,bx=bx,ax end
    if(ay>by) then ay,by=by,ay end
    if(az>bz) then az,bz=bz,az end
    local total=(bx-ax+1)*(by-ay+1)*(bz-az+1)
    local cnt=1
    local world=debugcard.getWorld()
    for x=ax,bx,1 do
        for y=ay,by,1 do
            for z=az,bz,1 do
                print("Adding Block (" .. x .. "," .. y .. "," .. z .. ") " .. cnt .. " of " .. total .. " [" .. cnt*100/total .. "%]")
                if(not world.isLoaded(x,y,z)) then
                    error("Block (" .. x .. "," .. y .. "," .. z .. ") is not loaded.")
                end
                local t={}
                t.x=x-ax
                t.y=y-ay
                t.z=z-az
                t.id=world.getBlockId(x,y,z)
                t.meta=world.getMetadata(x,y,z)
                local xnbt=world.getTileNBT(x,y,z)
                if(xnbt~=nil) then
                    t.nbt=xnbt
                end
                table.insert(box,t)
                cnt=cnt+1
            end
        end
    end
    return box
end

-- Act like CopyArea, but no air blocks are recorded.
function CopyAreaWithoutAir(ax,ay,az,bx,by,bz)
    local debugcard=component.debug
    if(debugcard==nil) then
        error("This program require debug card.")
    end

    local box={}
    if(ax>bx) then ax,bx=bx,ax end
    if(ay>by) then ay,by=by,ay end
    if(az>bz) then az,bz=bz,az end
    local total=(bx-ax+1)*(by-ay+1)*(bz-az+1)
    local cnt=1
    local world=debugcard.getWorld()
    for x=ax,bx,1 do
        for y=ay,by,1 do
            for z=az,bz,1 do
                print("Adding Block (" .. x .. "," .. y .. "," .. z .. ") " .. cnt .. " of " .. total .. " [" .. cnt*100/total .. "%]")
                if(not world.isLoaded(x,y,z)) then
                    error("Block (" .. x .. "," .. y .. "," .. z .. ") is not loaded.")
                end
                local t={}
                t.id=world.getBlockId(x,y,z)
                if(t.id~=0) then
                    t.x=x-ax
                    t.y=y-ay
                    t.z=z-az
                    t.meta=world.getMetadata(x,y,z)
                    local xnbt=world.getTileNBT(x,y,z)
                    if(xnbt~=nil) then
                        t.nbt=xnbt
                    end
                    table.insert(box,t)
                    cnt=cnt+1
                else
                    total=total-1
                end
            end
        end
    end
    return box
end

-- Act like CopyArea, but store block ID in string type.
function CopyAreaStrID(ax,ay,az,bx,by,bz)
    local debugcard=component.debug
    if(debugcard==nil) then
        error("This program require debug card.")
    end

    local box={}
    if(ax>bx) then ax,bx=bx,ax end
    if(ay>by) then ay,by=by,ay end
    if(az>bz) then az,bz=bz,az end
    local total=(bx-ax+1)*(by-ay+1)*(bz-az+1)
    local cnt=0
    local world=debugcard.getWorld()
    for x=ax,bx,1 do
        for y=ay,by,1 do
            for z=az,bz,1 do
                cnt=cnt+1
                print("Adding Block (" .. x .. "," .. y .. "," .. z .. ") " .. cnt .. " of " .. total .. " [" .. cnt*100/total .. "%]")
                if(not world.isLoaded(x,y,z)) then
                    error("Block (" .. x .. "," .. y .. "," .. z .. ") is not loaded.")
                end
                local t={}
                t.x=x-ax
                t.y=y-ay
                t.z=z-az
                local blkstate=world.getBlockState(x,y,z)
                local blklftidx=string.find(blkstate,"[",1,true)
                if(blklftidx~=nil) then
                    -- minecraft:grass[snowy=false]
                    t.id=string.sub(blkstate,1,blklftidx-1)
                else
                    -- minecraft:gold_block
                    t.id=blkstate
                end
                t.meta=world.getMetadata(x,y,z)
                local xnbt=world.getTileNBT(x,y,z)
                if(xnbt~=nil) then
                    t.nbt=xnbt
                end
                table.insert(box,t)
            end
        end
    end
    return box
end

function PasteArea(box,ax,ay,az)
    local debugcard=component.debug
    if(debugcard==nil) then
        error("This program require debug card.")
    end

    local cnt=0
    local world=debugcard.getWorld()
    for k,v in ipairs(box) do
        print("Pasting to (" .. ax+v.x .. "," .. ay+v.y .. "," .. az+v.z .. ")")
        world.setBlock(ax+v.x,ay+v.y,az+v.z,v.id,v.meta)
        if(v.nbt~=nil) then
            world.setTileNBT(x,y,z,v.nbt)
        end
        cnt=cnt+1
    end
    print("Pasted " .. cnt .. " blocks.")
    return cnt  
end

