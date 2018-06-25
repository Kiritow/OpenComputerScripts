-- Storage Manager
-- Designed for survival mode playing

require("libevent")
local component=require("component")
local sides=require("sides")
local term=require("term")

local gpu=component.proxy(component.list("gpu")())

local function fullScan()
    local device_gate=component.list("transposer")
    if(device_gate==nil) then return {} end
    local devices={}
    while true do
        local addr=device_gate()
        if(addr==nil) then break end
        table.insert(devices,addr)
    end

    local allprog=(#devices)*4

    local db={}
    local allsides={ sides.north, sides.east, sides.south, sides.west }

    local done=0

    for _,addr in pairs(devices) do
        local dev=component.proxy(addr)
        for _,cside in pairs(allsides) do
            local x=dev.getAllStacks(cside)
            local cnt=x.count()
            for i=1,cnt,1 do
                local t=x()
                if(t.name~=nil) then
                    if(db[t.name]~=nil) then
                        db[t.name]=db[t.name]+t.size
                    else
                        db[t.name]=t.size
                    end
                end
            end
            done=done+1
            PushEvent("scan_progress",done/allprog)
        end
    end

    return db
end

local item_db={}

local function ui_clear()
    local w,h=gpu.getResolution()
    gpu.fill(1,1,w,h,' ')
end

local function ui_show(page_id)
    local w,h=gpu.getResolution()
    gpu.fill(1,1,w,1,'=')
    gpu.set(5,1,"Storage Manager v0.1")
    gpu.fill(1,h,w,1,' ')
    gpu.set(1,h,"Status: Loading...")
    local item_to_skip=(page_id-1)*(h-2)
    local skipped=0
    local now=2
    for k,v in pairs(item_db) do
        if(skipped>=item_to_skip) then
            gpu.set(1,now,k .. " -- Count: " .. v)
            now=now+1
            if(now==h) then break end
        else
            skipped=skipped+1
        end
    end
    gpu.fill(1,h-3,w,1,' ')
    gpu.set(1,h-3,"<REFRESH>")
    gpu.fill(1,h-2,w,1,' ')
    gpu.set(1,h-2,"<PREV>")
    gpu.fill(1,h-1,w,1,' ')
    gpu.set(1,h-1,"<NEXT>")
    gpu.fill(1,h,w,1,' ')
    gpu.set(1,h,"Status: Ready. Page " .. page_id)
end

local function ui_fullscan()
    ui_clear()
    gpu.set(1,1,"Please wait while full scanning...")
    local w,h=gpu.getResolution()

    local id=AddEventListener("scan_progress",function(e) 
        gpu.fill(1,2,w,1,' ')
        gpu.fill(1,2,e.data[1]*w,1,'=')
        gpu.set(1,2,"[" .. math.ceil(e.data[1]*100) .. "%>")
    end)

    item_db=fullScan()
    RemoveEventListener(id)
end

local current_page=1

local function ui_view()
    while true do
        local e=WaitEvent("touch")
        local w,h=gpu.getResolution()
        
        if(e.y==h-3) then
            ui_fullscan()
            return
        end

        if(e.y==h-2) then
            if(current_page>1) then
                current_page=current_page-1
                return
            end
        end
        
        if(e.y==h-1) then
            current_page=current_page+1
            return
        end
        if(e.y~=1 and e.y~=h) then
            -- Selected one row
            local count=1
            while true do
                term.setCursor(1,h)
                term.clearLine()
                io.write("Input number here:")
                term.setCursorBlink(true)
                count=io.read("n")
                if(count~=nil) then
                    break
                end
            end
        end
    end
end

local function ui_main()
    while true do
        ui_clear()
        ui_show(current_page)
        ui_view()
    end
end

local function main()
    ui_fullscan()
    ui_main()
end

main()