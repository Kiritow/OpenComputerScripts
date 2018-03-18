-- LibBundle - Bundle multiple files into a single one
-- Author: Github/Kiritow

function Bundle(file_table,bundle_file)
    local f=io.open(bundle_file,"wb")
    if(f==nil) then error("Output file can't be opened") end
    local cnt=0
    local info={}
    for k,v in pairs(file_table) do
        local x=io.open(v,"rb")
        if(x==nil) then 
            f:close()
            error("Failed to read file: " .. v)
        end
        local sz=x:seek("end")
        table.insert(info,{
            ["name"]=v,
            ["size"]=sz
        })
        x:close()
        cnt=cnt+1
    end
    f:write(string.char(string.len(tostring(cnt))),cnt)
    for i=1,cnt,1 do
        local namelen=string.len(info[i].name)
        f:write(string.char(string.len(tostring(namelen))),
            namelen,
            info[i].name)
        local sizelen=string.len(tostring(info[i].size))
        f:write(string.char(string.len(tostring(sizelen))),
            sizelen,
            info[i].size)
    end
    for i=1,cnt,1 do
        local x=io.open(info[i].name,"rb")
        local s=x:read("*a")
        f:write(s)
        x:close()
    end
    f:close()
    return cnt
end


function Unbundle(bundle_file)
    local f=io.open(bundle_file,"rb")
    if(f==nil) then error("Input bundle file not found.") end
    local psz=string.byte(f:read(1))
    local cnt=tonumber(f:read(psz))
    local info={}
    for i=1,cnt,1 do
        psz=string.byte(f:read(1))
        local namelen=tonumber(f:read(psz))
        local name=f:read(namelen)
        psz=string.byte(f:read(1))
        local sizelen=tonumber(f:read(psz))
        local size=tonumber(f:read(sizelen))
        table.insert(info,{
            ["name"]=name,
            ["size"]=size
        })
    end
    for i=1,cnt,1 do
        local x=io.open(info[i].name,"wb")
        if(x==nil) then 
            f:close()
            error("Output file not found: " .. info[i].name)
        end
        local s=f:read(info[i].size)
        x:write(s)
        x:close()
    end
    return cnt,info
end