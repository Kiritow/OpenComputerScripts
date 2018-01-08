local component=require("component")
local sides=require("sides")
local thread=require("thread")
require("libevent")
require("libnetbox")
require("util")

--- Auto Configure
local digital_controller = proxy("digital_controller_box")
local digital_receiver = proxy("digital_receiver_box")
local out_ticket = proxy("routing_track")

--- Manually Configure
local load_detector = proxy("digital_detector","8")
local unload_detector = proxy("digital_detector","1")

local load_transposer = proxy("transposer","c")
local unload_transposer = proxy("transposer","5")

local route_ab_load = proxy("routing_switch","c")
local route_ba_load = proxy("routing_switch","6")
local route_ab_unload = proxy("routing_switch","8")
local route_ba_unload = proxy("routing_switch","2")

--- Internal Variables
local load_box_side
local unload_box_side
local loading=0 -- 0 Free 1 Ready 2 Processing
local unloading=0
local lockway=0 -- 0 Free 1 Loading 2 Unloading

-- Value: 1 Green 2 Blinking Yellow 3 Yellow 4 Blinking Red 5 Red
local green=1
local byellow=2
local yellow=3
local bred=4
local red=5

local function setSignal(name,value)
    digital_controller.setAspect(name,value)
end

local function checkDevice()
    print("Checking Devices...")

    local function doCheckDevice(device)
        if(device==nil) then 
            error("Some device is nil. Please double check your configure.")
        end
    end

    doCheckDevice(digital_controller)
    doCheckDevice(digital_receiver)
    doCheckDevice(out_ticket)
    
    doCheckDevice(load_detector)
    doCheckDevice(unload_detector)
    doCheckDevice(route_ab_load)
    doCheckDevice(route_ba_load)
    doCheckDevice(route_ab_unload)
    doCheckDevice(route_ba_unload)

    local t=digital_controller.getSignalNames()

    local function checkSigName(name)
        local found=false
        for k,v in pairs(t) do 
            if(v==name) then
                return true
            end
        end
        error("CheckSigName: Failed to check signal: " .. name)
    end

    checkSigName("AInCtrl")
    checkSigName("BInCtrl")
    checkSigName("LoadCartCtrl")
    checkSigName("LoadBoxCtrl")
    checkSigName("LoadLamp")
    checkSigName("UnloadCartCtrl")
    checkSigName("UnloadBoxCtrl")
    checkSigName("UnloadLamp")
    checkSigName("OutCtrl")
    checkSigName("OutSwitchCtrl")

    t=digital_receiver.getSignalNames()
    local function checkSigNameX(name)
        checkSigName(name)
        if(digital_receiver.getAspect(name)~=red) then
            error("CheckSigNameX: Failed to check cart signals. Value must be red while initializing.")
        end
    end

    checkSigNameX("LoadCartSig")
    checkSigNameX("UnloadCartSig")

    local function checkRoutingTable(device)
        if(device.getRoutingTableTitle()==false) then 
            error("CheckRoutingTable: Failed to check routing table. Please insert a routing table in it.")
        end
    end

    checkRoutingTable(route_ab_load)
    checkRoutingTable(route_ba_load)
    checkRoutingTable(route_ab_unload)
    checkRoutingTable(route_ba_unload)

    local function checkRoutingTicket(device)
        if(device.getDestination()==false) then 
            error("CheckRoutingTicket: Failed to check routing track. Please insert a golden ticket in it.")
        end
    end

    checkRoutingTicket(out_ticket)

    local function checkChest(device)
        if(device.getInventorySize(sides.down)==nil) then 
            error("CheckChest: Failed to check chest. Cache Chest must exists.")
        end

        for i=1,device.getInventorySize(sides.down),1 do
            if(device.getStackInSlot(sides.down,i)~=nil) then
                error("CheckChest: Failed to check chest. Cache Chest not empty.")
            end
        end

        local tsd

        local dr={sides.north,sides.south,sides.east,sides.west}
        for k,v in pairs(dr) do 
            if(device.getInventorySize(v)~=nil) then
                tsd=v
            end
        end

        if(tsd==nil) then
            error("CheckChest: Failed to check chest. Normal Chest must exists.")
        end

        for i=1,device.getInventorySize(tsd),1 do
            if(device.getStackInSlot(tsd,i)~=nil) then
                error("CheckChest: Failed to check chest. Normal Chest not empty.")
            end
        end

        return tsd
    end

    load_box_side=checkChest(load_transposer)
    unload_box_side=checkChest(unload_transposer)

    print("Check device pass.")
end

local function resetDevice()
    print("Reseting Devices...")

    digital_controller.setEveryAspect(red)
    setSignal("UnloadBoxCtrl",green) --- Lock unload box.
    setSignal("LoadLamp",green)
    
    route_ab_load.setRoutingTable({})
    route_ba_load.setRoutingTable({})
    route_ab_unload.setRoutingTable({})
    route_ba_unload.setRoutingTable({})

    print("Device reset done.")
end

local function setLoadLamp(sigcolor)
    setSignal("LoadLamp",sigcolor)
end

local function setUnloadLamp(sigcolor)
    setSignal("UnloadLamp",sigcolor)
end

local function lockLoadChest()
    setSignal("LoadBoxCtrl",green)
end

local function unlockLoadChest()
    setSignal("LoadBoxCtrl",red)
end

local function lockUnloadChest()
    setSignal("UnloadBoxCtrl",green)
end

local function unlockUnloadChest()
    setSignal("UnloadBoxCtrl",red)
end


local function getNewTransID(cnt)
    print("Getting new transfer id...")
    OpenPort(10011)
    BroadcastData(10010,"TSCM","req","store",cnt)
    e=WaitEvent("net_message",10)
    local ret
    if(e~=nil and e.data[1]=="TSCM" and e.data[2]=="ack" and e.data[3]=="pass") then
        ret=e.data[4]
    else
        ret=nil
    end
    ClosePort(10011)
    return ret
end

local function SetTicket(Dest)
    out_ticket.setDestination(Dest)
end

local function doLoadWork(item_cnt)
    print("LoadWork: Ready.")
    local id=getNewTransID(item_cnt)
    if(id==nil) then 
        print("LoadWork: Failed to get new transID.")
        print("LoadWork: item rollback started.")

        setLoadLamp(byellow)
        local sz=load_transposer.getInventorySize(sides.down)
        local cnt=1
        for i=1,sz,1 do 
            if(load_transposer.getStackInSlot(sides.down,i)~=nil) then 
                load_transposer.transferItem(sides.down,load_box_side)
                cnt=cnt+1
            end
        end

        print("LoadWork: item rollback finished.")
        loading=0
        setLoadLamp(green)
        unlockLoadChest()
    else
        id=math.ceil(id)
        print("LoadWork: Transfer id got.")
        print("LoadWork: Setting routing table...")
        local trainid="TC_" .. tostring(id)
        local routestr="Dest=" .. trainid
        print("LoadWork: ",routestr)
        local routetb={[1]=routestr}
        route_ab_load.setRoutingTable(routetb)
        route_ba_load.setRoutingTable(routetb)

        local backtrainid="TR_" .. tostring(id)

        print("LoadWork: Routing table set.")

        local bus=CreateEventBus()
        EventBusListen(bus,"minecart")

        local function trigger()
            setSignal("LoadCartCtrl",green)
            os.sleep(0.5)
            setSignal("LoadCartCtrl",red)
        end

        local function lockOutWay()
            while(lockway~=0) do 
                os.sleep(1)
            end
            lockway=1
        end

        local function unlockOutWay()
            lockway=0
        end

        local function startOutWay()
            setSignal("OutCtrl",green)
            os.sleep(0.5)
            setSignal("OutCtrl",red)
        
            unlockOutWay()
        end

        while true do
            local e=GetNextEvent(bus)
            if(e.event=="minecart") then
                print("LoadWork: Minecart arrived. Start Loading...")
                if(e.minecartType=="locomotive_creative") then 
                    print("LoadWork: Skipping locomotive.")
                    print("LoadWork: Try locking outway...")
                    lockOutWay()
                    print("LoadWork: Outway locked.")
                    SetTicket(backtrainid)
                    setLoadLamp(red)
                elseif(e.minecartType=="cart_chest") then
                    print("LoadWork: Filling chest cart...")
                    while(digital_receiver.getAspect("LoadCartSig")==red) do
                        os.sleep(1)
                    end
                    print("LoadWork: Chest cart filled.")
                    trigger()
                elseif(e.minecartType=="cart_worldspike_admin") then
                    print("LoadWork: Found world spike. Finish.")
                    trigger()
                    trigger()

                    startOutWay()
                    break
                else
                    print("LoadWork: Skipping unknown cart_type: " .. e.minecartType)
                    trigger()
                end
            end
        end

        DestroyEventBus(bus)

        --- Clean Up
        setLoadLamp(green)
        unlockLoadChest()
    end
end

local function startLoad()
    if(loading>0) then
        return false,"Loading status not free"
    end

    lockLoadChest()

    local sz=load_transposer.getInventorySize(load_box_side)
    local cnt=1
    for i=1,sz,1 do 
        if(load_transposer.getStackInSlot(load_box_side,i)~=nil) then 
            load_transposer.transferItem(load_box_side,sides.down)
            cnt=cnt+1
        end
    end

    print("startLoad: " .. cnt-1 .. " item transferred to internal chest")
    loading=1
    thread.create(doLoadWork,cnt);

    setLoadLamp(yellow)
    print("Info: You items have been submitted.")
end

local function storeMain()
    setLoadLamp(byellow)
    print("Please put your items to inbox.")
    print("Once you finished it, press enter")
    io.read()
    print("Start loading...")
    startLoad()
end

local function main()
    checkDevice()
    resetDevice()

    NetBoxInit()

    while true do
        print(
            "-------------\n" ..
            "Action List\n" ..
            "1 Store items\n" ..
            "2 Get items\n" ..
            "3 Exit\n" ..
            "-------------"
        )
        local id=io.read("*num")
        io.read()
        if(id==1) then 
            storeMain()
        elseif(id==2) then 
            getMain()
        elseif(id==3) then
            break
        end
    end

    resetDevice()
    unlockUnloadChest()

    NetBoxCleanUp()
end

print("Transport System Client Started.")
print("Author: Kiritow")
main()
print("Transport System Client Stopped.")