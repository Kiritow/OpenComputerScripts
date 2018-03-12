local component=require("component")

-- Hardware check
local debugcard=component.debug

if(debugcard==nil) then
    error("This program require debug card.")
end

function CopyArea(ax,ay,az,bx,by,bz)
    local box={}
    if(ax>bx) then ax,bx=bx,ax end
    if(ay>by) then ay,by=by,ay end
    if(az>bz) then az,bz=bz,az end
    local total=(bx-ax+1)*(by-ay+1)*(bz-az+1)
    local cnt=0
    for x=ax,bx,1 do
        for y=ay,by,1 do
            for z=az,bz,1 do
                cnt=cnt+1
                print("Adding Block (" .. x .. "," .. y .. "," .. z .. ") " .. cnt .. " of " .. total .. " [" .. cnt*100/total .. "%]")
                if(not debugcard.getWorld().isLoaded(x,y,z)) then
                    error("Block (" .. x .. "," .. y .. "," .. z .. ") is not loaded.")
                end
                local t={}
                t.x=x
                t.y=y
                t.z=z
                t.id=debugcard.getWorld().getBlockId(x,y,z)
                t.meta=debugcard.getWorld().getMetadata(x,y,z)
                table.insert(box,t)
            end
        end
    end
    return box
end

function PasteArea(box,ax,ay,az)
    local cnt=0
    local world=debugcard.getWorld()
    for k,v in ipairs(box) do
        print("Pasting to (" .. ax+v.x .. "," .. ay+v.y .. "," .. az+v.z .. ")")
        world.setBlock(ax+v.x,ay+v.y,az+v.z,v.meta)
        cnt=cnt+1
    end
    return cnt  
end
