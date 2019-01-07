-- Compress command line tool
-- Powered by libcompress

local shell=require('shell')
local libcompress=require('libcompress')
local args,opts=shell.parse(...)

if(args<2) then
    print("Usage:\n\tcompress [-dv] <source> <dest>")
end

local verbose=opts["v"] and print or function() end

local f=io.open(args[1],"rb")
if(not f) then
    print("[Error] Failed to open file for read: " .. args[1])
    return
end
local str=f:read("a")
f:close()

local nSource=str:len()
str=opts["d"] and libcompress.inflate(str) or libcompress.deflate(str)
local nDest=str:len()
verbose(string.format("SourceLen: %d DestLen: %d Rate: %.2f",nSource,nDest,nDest/nSource))

f=io.open(args[2],"wb")
if(not f) then
    print("[Error] Failed to open file for write: " .. args[2])
    return
end 

local ok,msg=f:write(str)
f:close()

if(not ok) then
    print("[Error] Failed to write file: " .. args[2] .. ": " .. msg)
    return
end