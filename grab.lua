-- Grab : OpenComputerScripts Installer
-- Created By Kiritow
local computer=require('computer')
local component=require('component')
local shell=require('shell')
local filesystem=require('filesystem')
local serialization=require('serialization')
local args,options=shell.parse(...)
local nOptions=0
for k,v in pairs(options) do nOptions=nOptions+1 end
if( (#args<1 and nOptions<1) or options["help"]) then
    print("Grab - Official OpenComputerScripts Installer")
    print("Usage:\n\tgrab [<options>] <command> [<projects>]")
    print("Options:"
        .. "\n\t--cn Use mirror site in China. By default grab will download from Github."
        .. "\n\t--help Display this help page."
        .. "\n\t--version Display version and exit."
        .. "\n\t--proxy=<Proxy File> Given a proxy file which will be loaded and returns a proxy function like: "
        ..      "function(RepoName: string, Branch: string ,FileAddress: string): string"
    )
    print("Command:"
        .. "\n\tinstall, list, update"
    )
    return 
end
if(options["version"]) then
    print("Grab v2.0-beta")
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
if(not options["proxy"]) then
    if(not options["cn"]) then 
        UrlGenerator=function(RepoName,Branch,FileAddress)
            return "https://raw.githubusercontent.com/" .. RepoName .. "/" .. Branch .. "/" .. FileAddress
        end
    else
        UrlGenerator=function(RepoName,Branch,FileAddress)
            return "http://kiritow.com:3000/" .. RepoName .. "/raw/" .. Branch .. "/" .. FileAddress
        end
    end
else
    local ok,err=pcall(function()
        local f=io.open(options["proxy"],"r")
        if(f==nil) then error("Proxy file not found") end
        local src=f:read("a")
        f:close()
        local fn=load(src)
        UrlGenerator=fn()
    end)
    if(not ok) then
        print("Proxy file error: " .. err)
        return
    end
end

local db_dirs={"/etc/grab",".grab","/tmp/.grab"}
local db_positions={"/etc/grab/programs.info",".grab/programs.info","/tmp/.grab/programs.info"}

local function CheckAndLoad(raw_content)
    local fn,err=load(raw_content)
    if(fn) then 
        local ok,result=pcall(fn)
        if(ok) then return result
        else return nil,result end
    end
    return nil,err
end

local function ReadDB()
    for idx,filename in ipairs(db_positions) do 
        local f=io.open(filename,"r")
        if(f) then
            local result=serialization.unserialize(f:read("*a"))
            f:close()
            return result,filename
        end
    end
    return nil
end

local function WriteDB(filename,tb,is_raw) -- By default, is_raw=false
    local f=io.open(filename,"w")
    if(f) then 
        if(not is_raw) then f:write(serialization.serialize(tb))
        else f:write(tb) end
        f:close()
        return true
    end
    return false
end

local function CreateDB(tb,is_raw)
    for idx,dirname in ipairs(db_dirs) do
        filesystem.makeDirectory(dirname) -- buggy
    end
    for idx,filename in ipairs(db_positions) do
        if(WriteDB(filename,tb,is_raw)) then
            return filename
        end
    end
    return nil
end

if(args[1]=="update") then
    print("Updating programs info....")
    io.write("Downloading... ")
    local ok,result,code=download(UrlGenerator("Kiritow/OpenComputerScripts","master","programs.info"))
    if(not ok) then
        print("[Failed] " .. result)
    elseif(code~=200) then
        print("[Failed] response code " .. code .. " is not 200.")
    else
        print("[OK]")
        io.write("Validating... ")
        local tb_data,validate_err=CheckAndLoad("return " .. result)
        result=nil -- release memory
        if(tb_data) then
            print("[OK]")
            io.write("Saving files... ")
            local dbfilename=CreateDB(tb_data)
            if(dbfilename) then
                print("[OK]")
                print("Programs info updated and saved to " .. dbfilename)
            else
                print("[Failed] Unable to save programs info")
            end
        else
            print("[Failed]" .. validate_err)
        end
    end

    return 
end

local db,dbfilename=ReadDB()

if(args[1]=="install") then
    if(#args<2) then 
        print("Nothing to install.")
        return
    else
        print("Checking programs info...")
    end

    local to_install={}
    for i=2,#args,1 do
        to_install[args[i]]=true
    end

    local newly_added=0
    while true do
        local to_add={}
        for this_lib in pairs(to_install) do
            if(not db[this_lib]) then
                print("Library '" .. this_lib .. "' not found.")
                return
            else
                if(db[this_lib].requires) then
                    for idx,this_req in ipairs(db[this_lib].requires) do
                        if(not to_install[this_req] and not to_add[this_req]) then
                            newly_added=newly_added+1
                            to_add[this_req]=true
                        end
                    end
                end
            end
        end
        for this_lib in pairs(to_add) do
            to_install[this_lib]=true
        end
        if(newly_added==0) then break 
        else
            newly_added=0
        end
    end

    print("About to install the following libraries...")
    local count_libs=0
    local count_files=0
    for this_lib in pairs(to_install) do
        io.write(this_lib .. " ")
        count_libs=count_libs+1
        for k in ipairs(db[this_lib].files) do
            count_files=count_files+1
        end
    end
    print("\n" .. count_libs .. " libraries will be installed. " .. count_files .. " will be downloaded.")

    local time_before=computer.uptime()

    print("Downloading...")
    local id_installing=1
    for this_lib in pairs(to_install) do
        for k,v in ipairs(db[this_lib].files) do
            local toDownload
            if(type(k)=="number" and type(v)=="string") then
                toDownload=v
            elseif(type(k)=="string") then
                toDownload=k
            else
                print("Invalid programs info: key type: " .. type(k) .. ". value type: " .. type(v))
                return
            end

            io.write("[" .. id_installing .. "/" .. count_files .. "] Downloading " .. toDownload .. " for " .. this_lib .. "... ")
            local ok,result,code=download(UrlGenerator("Kiritow/OpenComputerScripts","master",toDownload))
            if(not ok) then 
                print("[Download Failed] " .. result)
                return
            elseif(code~=200) then
                print("[Download Failed] response code " .. code .. " is not 200.")
                return 
            else
                if(type(v)=="string") then
                    local f=io.open(v,"w")
                    if(f==nil) then
                        print("[Error] Unable to write to file " .. v)
                        return
                    else
                        f:write(result)
                        f:close()
                        print("[OK]")
                    end
                elseif(type(v)=="table") then
                    local success=false
                    for idx,value in ipairs(v) do
                        local f=io.open(value,"w")
                        if(f) then
                            success=true
                            f:write(result)
                            f:close()
                            print("[OK]")
                        end
                    end
                    if(not success) then
                        print("[Error] Unable to write file: " .. toDownload)
                        return 
                    end
                end
            end
        end
    end

    print("Installed " .. count_libs .. " libraies with " .. count_files .. " files in " .. computer.uptime()-time_before .. " seconds.")
    return
end

if(args[1]=="list") then
    print("Listing projects...")
    for this_lib in pairs(db) do
        print(this_lib)
    end

    return
end

-- reach here? 
print("Invalid argument 1: " .. args[1])