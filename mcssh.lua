local component=require("component")

local function myPrint(...)
    return io.write(...)
end

function doRunSSH(sock)
    local cmdLength=0
    local cmdLengthTmpStr=""
    local cmdLengthLeftBit=4
    while true do
        local s=sock.read(cmdLengthLeftBit)
        if(s==nil) then return
        else
            cmdLengthTmpStr=cmdLengthTmpStr .. s
            cmdLengthLeftBit=cmdLengthLeftBit-string.length(s)
            if(cmdLengthLeftBit==0) then -- Receive 4B length
                cmdLength=tonumber(cmdLengthTmpStr)
                cmdLengthTmpStr="" -- Reset TmpStr
                -- Start Data Receive
                local cmdText=""
                local done=0
                while (done<cmdLength) do
                    s=sock.read(cmdLength-done)
                    if(s==nil) then return end-- Connection Closed.
                    done=done+string.length(s)
                    cmdText=cmdText .. s
                end
                -- Command received. Write to a temp file
                -- This is because OC-Lua does not implements loadstring(). So we use dofile() instead
                local fd=io.open("/tmp/a.lua","w")
                fd:write(cmdText)
                fd:close()
                -- Replace output
                local oldprint=print
                print=oldprint
                io.open("/tmp/a.txt")
                -- Call dofile
                dofile("/tmp/a.lua")
                -- Switch back
                io.close()
                print=oldprint

                -- Send Result back
                local hand=io.open("/tmp/a.txt","r")
                local resText=hand:read("a")
                hand:close()
                local resLen=tostring(string.length(resText))
                sock.send(resLen)
                sock.send(resText)
            end
        end
    end
end

function runSSH(ServerIP,ServerPort)
    local x=component.internet.connect(ServerIP,ServerPort)
    doRunSSH(x)
    x.close()
end