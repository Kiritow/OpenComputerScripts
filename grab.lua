-- Grab : OpenComputerScripts Installer
-- Created By Kiritow
local component=require('component')
local shell=require('shell')
local args,options=shell.parse(...)
if( (#args<1 and (not options["setup"])) or options["help"]) then
    print("Grab : OpenComputerScripts Installer")
    print("Usage:\n\tgrab [options] [files]")
    print("Options:"
        .. "\n\t--cn Use mirror site in China. By default grab will download from Github."
        .. "\n\t--help Display this help page."
        .. "\n\t--setup Download some basic files for development"
    )
    return 
end
local function download(url)
    if(component.internet==nil) then
        error("This program requires an Internet card.")
    end
    local handle=component.internet.request(url)
    while true do
        local ret,err=handle.finishConnect()
        if(ret==nil) then
            return false,err
        elseif(ret==true) then 
            break 
        end
    end
    local code=handle.response()
    local result=''
    while true do 
        local temp=handle.read()
        if(temp==nil) then break end
        result=result .. temp
    end
    handle.close()
    return true,result,code
end
local UrlGenerator
if(not options["cn"]) then 
    UrlGenerator=function(RepoName,Branch,FileAddress)
        return "https://raw.githubusercontent.com/" .. RepoName .. "/" .. Branch .. "/" .. FileAddress
    end
else
    UrlGenerator=function(RepoName,Branch,FileAddress)
        return "http://kiritow.com:3000/" .. RepoName .. "/raw/" .. Branch .. "/" .. FileAddress
    end
end
local files
if(options["setup"]) then
    files={"LICENSE","checkarg.lua","libevent.lua","class.lua","util.lua"}
else
    files=args
end
print('Downloading...')
for idx,filename in ipairs(files) do
    io.write("[" .. idx .. "/" .. #files .. "] " .. filename)
    local ok,err=pcall(function()
        local flag,result,code=download(UrlGenerator("Kiritow/OpenComputerScripts","master",filename))
        if(not flag) then 
            print(" [Download Failed] " .. result)
        elseif(code~=200) then
            print(" [Download Failed] response code " .. code .. " is not 200.")
        else
            local f=io.open(filename,"w")
            f:write(result)
            f:close()
            print(" [OK]")
        end
    end)
    if(not ok) then
        print(" [Error] " .. err)
    end
end