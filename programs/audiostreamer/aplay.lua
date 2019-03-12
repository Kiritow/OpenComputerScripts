local component=require('component')
local term=require('term')
local download=require('libdownload').download

local function string_split(str,sep)
    local sep,fields=sep or '\t',{}
    local pattern = string.format("([^%s]+)", sep)
    string.gsub(str, pattern, function(c) table.insert(fields,c) end)
    return fields
end

local network=component.list('internet')()
if(not network) then
    print("This program requires an internet card to run.")
    return
else
    network=component.proxy(network)
end

local tape_drive=component.list('tape_drive')()
if(not tape_drive) then
    print("This program requires a tape_drive to run.")
    return
else
    tape_drive=component.proxy(tape_drive)
end

print('Fetching music list...')
local ok,data,code=download("http://localhost:59612/list",{device=network})
if(not ok or code~=200) then
    print("[Failed] " .. data)
    return
end

local fields=string_split(data,'\n')
if(fields[1]==string.rep('=',10) and 
    fields[#fields]==string.rep('=',10)) then
    table.remove(fields)
    table.remove(fields,1)
else
    print("[Failed] Received corrupted data.")
end

for idx,name in ipairs(fields) do
    print(string.format("[%d] %s",idx,name))
end

io.write("Input id to play music: ")
local userInput=tonumber(io.read())
if(userInput<1 or userInput>#fields) then
    print("Input out of range.")
    return
end

print("Stopping tape drive...")
tape_drive.stop()
print("Seeking tape drive...")
tape_drive.seek(-1-tape_drive.getPosition())

print("Downloading music...")
local content_length=1
local data_received=0
local ok,data,code=download("http://localhost:59612/music",{device=network,
    data=fields[userInput],
    onresponse=function(code,msg,headers)
        if(code~=200) then
            print("Response code not equals to 200.")
            return true 
        end
        if(headers["Content-Length"]) then
            content_length=tonumber(headers["Content-Length"][1]) // 1
        end
    end,
    ondata=function(data)
        data_received=data_received+#data
        tape_drive.write(data)
        term.clearLine()
        io.write(string.format("%d of %d bytes received. (%.2f%%)",data_received,content_length,100.0*data_received/content_length))
    end
})

if(not ok and code~=200) then
    print("[Failed] " .. data)
    return
end

print()
print("Seeking to front...")
tape_drive.seek(-1-tape_drive.getSize())
print("Playing...")
tape_drive.play()

print("[Done] Enjoy it. " .. fields[userInput])
