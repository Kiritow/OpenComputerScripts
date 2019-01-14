-- EEPROM Maker
-- Created by Kiritow.
local computer=require('computer')
local unicode=require('unicode')
local component=require('component')
local filesystem=require('filesystem')
local shell=require('shell')
local uuid=require('uuid')

local shrink=require('shrinkfsm')
require('libevent')

local EEPROM_MAKER_VERSION="EEPROM Maker v1.5"

local args,opts=shell.parse(...)

if(opts["version"]) then
    print(EEPROM_MAKER_VERSION)
    return
end
if(opts["help"]) then
    print([=[EEPROM Maker
Usage:
    makerom <file> [-fcs] [--help] [--version]
Options:
    -f Skip romfile backup
    -c Check source before writing to eeprom. (Exp.)
    -s Shorten source code with shrinkFSM. (Exp.)
    --help Display this help and quit.
    --version Display the version and quit.
Notes:
    Romfile backup might be skipped if the eeprom is newly inserted.
    EEPROM Maker performs load-only checking on the source code. Currently this is an experimental feature and may report errors wrongly.
    EEPROM Maker use shrinkFSM to shorten the source code. Currently this is an experimental feature. The shortened code might act different from the original one.
]=])
    return
end

if(#args<1) then
    print("makerom: try 'makerom --help' for more information.")
    return
end

local function GetShadowCopy(tb)
    local t={}
    for k,v in pairs(tb) do
        t[k]=v
    end
    return t
end

local function GetROMEnv()
    -- bit32 is deprecated and is not included.
    local box={
        tostring=_G.tostring,
        ipairs=_G.ipairs,
        load=_G.load,
        select=_G.select,
        xpcall=_G.select,
        getmetatable=_G.getmetatable,
        rawget=_G.rawget,
        setmetatable=_G.setmetatable,
        rawlen=_G.rawlen,
        computer={
            freeMemory=computer.freeMemory,
            uptime=computer.uptime,
            setBootAddress=computer.setBootAddress,
            energy=computer.energy,
            tmpAddress=computer.tmpAddress,
            pullSignal=computer.pullSignal,
            maxEnergy=computer.maxEnergy,
            beep=computer.beep,
            pushSignal=computer.pushSignal,
            setArchitecture=computer.setArchitecture,
            address=computer.address,
            removeUser=computer.removeUser,
            getArchitecture=computer.getArchitecture,
            getProgramLocations=computer.getProgramLocations,
            shutdown=computer.shutdown,
            users=computer.users,
            getArchitectures=computer.getArchitectures,
            totalMemory=computer.totalMemory,
            getDeviceInfo=computer.getDeviceInfo,
            addUser=computer.addUser
        },
        coroutine=GetShadowCopy(_G.coroutine),
        string=GetShadowCopy(string),
        _VERSION=_G._VERSION,
        os={
            time=os.time,
            date=os.date,
            difftime=os.difftime,
            clock=os.clock
        },
        unicode=GetShadowCopy(unicode),
        debug=GetShadowCopy(_G.debug),
        math=GetShadowCopy(_G.math),
        tonumber=_G.tonumber,
        component={
            type=component.type,
            fields=component.fields,
            doc=component.doc,
            proxy=component.proxy,
            invoke=component.invoke,
            list=component.list,
            slot=component.slot,
            methods=component.methods
        },
        checkArg=_G.checkArg,
        assert=_G.assert,
        rawset=_G.rawset,
        pcall=_G.pcall,
        type=_G.pcall,
        table=GetShadowCopy(_G.table),
        rawequal=_G.rawequal,
        pairs=_G.pairs
    }
    box._G=box

    return box
end

local function CheckCode(src)
    local c,e=load(src,"UserEEPROM","t",GetROMEnv())
    if(c) then
        return true
    else
        return false,"SyntaxError: " .. e
    end
end

print("Loading file: " .. args[1])
local f=io.open(args[1],"rb")
if(not f) then
    print("[Error] Failed to open file: " .. args[1])
    return
end
local src=f:read("a")
f:close()

if(opts["c"]) then
    print("Checking source code...")
    local f,e=CheckCode(src)
    if(not f) then
        print("[Failed] Code checking failed (maybe wrong report): ")
        print(e)
        return
    end
    print("[OK] Code checking pass.")
end

if(opts["s"]) then
    print("Shorten code with shrinkFSM...")
    local oldLen=src:len()
    src=shrink(src)
    local newLen=src:len()
    print(string.format("[OK] Code shrinked: %d --> %d (%.2f%%)",oldLen,newLen,newLen/oldLen*100))
end

local eeprom=component.list("eeprom")()
local newlyInstalled=false
if(eeprom) then
    eeprom=component.proxy(eeprom)

    if(not opts["f"]) then
        local fname=os.tmpname()
        local f=io.open(fname,"wb")
        if(not f) then
            print("[Error] Failed to open file for writing: " .. fname)
            return
        end
        local h,e=f:write(eeprom.get())
        f:close()
        if(not h) then
            print("[Failed] Error while writing file: " .. e)
            return
        end
        print("Previous flash content saved to " .. fname)
    else
        print("Skipped flash content saving.")
    end
else
    print("No eeprom installed. Insert a new one or press Ctrl+C to abort.")
    while true do
        local e=WaitMultipleEvent("component_added","interrupted")
        if(e.event=="interrupted") then
            print("Aborted.")
            return
        elseif(e.type=="eeprom") then
            print("New eeprom: " .. e.address)
            eeprom=component.proxy(e.address)
            break
        end
    end
    newlyInstalled=true
end

-- eeprom.getSize() may be different if it has been changed in config.
if(src:len()>eeprom.getSize()) then
    print(string.format("[Error] Source too long. Length: %d, Capability: %d. %d more bytes needed.",src:len(),eeprom.getSize(),src:len()-eeprom.getSize()))
    return
end

if(not newlyInstalled) then
    print("Please insert new eeprom, or press Ctrl+C to skip.")
    while true do
        local e=WaitMultipleEvent("component_added","interrupted")
        if(e.event=="interrupted") then
            print("Skipped.")
            break
        elseif(e.type=="eeprom") then
            print("New eeprom: " .. e.address)
            eeprom=component.proxy(e.address)
            break
        end
    end
end

print("[Pending] WriteROM " .. eeprom.address)
print("Perform writing in 3s, press Ctrl+C to cancel.")
local e=WaitEvent(3,"interrupted")
if(e) then
    print("Aborted.")
    return
end
print("[Working] WriteROM " .. eeprom.address)
eeprom.set(src)

print("Set the label of new eeprom: (leave it blank to skip)")
local newName=io.read("l")
if(newName and newName:len()>0) then
    eeprom.setLabel(newName)
    print("eeprom renamed to " .. newName)
end
print("[Done] MakeROM finished.")
