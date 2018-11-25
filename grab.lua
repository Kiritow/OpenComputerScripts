-- Grab : Official OpenComputerScripts Installer
-- Created By Kiritow
local computer=require('computer')
local component=require('component')
local shell=require('shell')
local filesystem=require('filesystem')
local serialization=require('serialization')
local event=require('event')
local args,options=shell.parse(...)

local grab_version="Grab v2.3.1-alpha"

local valid_options={
    ["cn"]=true, ["help"]=true, ["version"]=true, ["proxy"]=true, ["skip_install"]=true
}
local valid_command={
    ["install"]=true,
    ["add"]=true,["update"]=true,["clear"]=true,
    ["list"]=true,["search"]=true,["show"]=true,
    ["download"]=true
}

local nOptions=0
for k,v in pairs(options) do 
    if(not valid_options[k]) then 
        if(string.len(k)>1) then print("Unknown option: --" .. k)
        else print("Unknown option: -" .. k) end
        return
    end
    nOptions=nOptions+1 
end

local function show_usage()
    print([===[Grab - Official OpenComputerScripts Installer
Usage:
    grab [<options>] <command> ...
Options:
    --cn Use mirror site in China. By default grab will download from Github.
    --help Display this help page."
    --version Display version and exit."
    --proxy=<Proxy File> Given a proxy file which will be loaded and returns a proxy function like: "
        function(RepoName: string, Branch: string ,FileAddress: string): string"
    --skip_install Library installers will not be executed.
Command:
    install <Project> ...: Install projects. Dependency will be downloaded automatically.
    add <Provider> ... : Add program provider info.
    update: Update program info.
    clear: Clear program info.
    list: List available projects.
    search <Name or Pattern> :  Search projects by name
    show <Project> : Show more info about project.
    download <Filename> ...: Directly download files. (Just like the old `update`!)
]===])
end

local function check_internet()
    if(component.internet==nil) then
        print("Error: An internet card is required to run this program.")
        return false
    else
        return true
    end
end

if( (#args<1 and nOptions<1) or options["help"]) then
    show_usage()
    return
end

if(options["version"]) then
    print(grab_version)
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
        else
            local ev=event.pull(0.5,"interrupted")
            if(ev~=nil) then 
                handle.close()
                return false,"Interrupted from terminal."
            end
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
        local fn,xerr=loadfile(options["proxy"])
        if(not fn) then error(xerr) 
        else UrlGenerator=fn() end
    end)
    if(not ok) then
        print("Unable to load proxy file: " .. err)
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

local function ReadDB(read_from_this)
    if(read_from_this) then
        local f=io.open(read_from_this,"r")
        if(f) then
            local result=serialization.unserialize(f:read("*a"))
            f:close()
            return result,filename
        else
            return nil
        end
    end

    for idx,filename in ipairs(db_positions) do 
        local a,b=ReadDB(filename)
        if(a) then return a,b end
    end

    return nil
end

local function WriteDB(filename,tb)
    local f=io.open(filename,"w")
    if(f) then 
        f:write(serialization.serialize(tb))
        f:close()
        return true
    end
    return false
end

local function UpdateDB(main_tb,new_tb) -- Change values with same key in main_tb to values in new_tb. Add new items to main_tb
    for k,v in pairs(new_tb) do
        main_tb[k]=v
    end
end

local function CreateDB(tb)
    for idx,dirname in ipairs(db_dirs) do
        filesystem.makeDirectory(dirname) -- buggy
    end
    for idx,filename in ipairs(db_positions) do
        local main_db=ReadDB(filename)
        if(main_db) then
            UpdateDB(main_db,tb)
            if(WriteDB(filename,main_db)) then
                return filename
            end
        else 
            if(WriteDB(filename,tb)) then
                return filename
            end
        end
    end
    return nil
end

if(args[1]=="clear") then
    print("Clearing programs info...")
    for idx,filename in pairs(db_positions) do
        filesystem.remove(filename)
    end
    print("Programs info cleaned. You may want to run `grab update` now.")
    return 
end

if(args[1]=="update") then
    if(not check_internet()) then return end

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

local function check_db()
    if(db) then return true
    else
        print("No programs info found on this computer.")
        print("Please run `grab update` first.")
        return false 
    end
end

if(args[1]=="add") then 
    if(#args<2) then 
        print("Nothing to add.")
    end

    if(not check_db()) then 
        return 
    end
    
    print("[WARN] Adding unofficial program providers may have security issues.")

    for i=2,#args,1 do
        local url=string.match(args[i],"^http[s]?://%S+")
        if(url==nil) then 
            local filename=args[i]
            local f=io.open(filename,"r")
            if(not f) then
                print("Unable to open local file: " .. filename)
            else
                local content=f:read("*a")
                f:close()
                local t,err=CheckAndLoad("return " .. content)
                if(t) then 
                    print("Updating with local file: " .. filename)
                    local fname=CreateDB(t)
                    if(fname) then
                        print("Programs info updated and saved to " .. fname)
                    else
                        print("Unable to update programs info.")
                    end
                else
                    print("Failed to load local file: " .. filename .. ". Error: " .. err)
                end
            end
        else
            print("Downloading from " .. url)
            local ok,result,code=download(url)
            if(not ok) then
                print("[Download Failed] " .. result)
            elseif(code~=200) then
                print("[Download Failed] Response code is not 200 but " .. code)
            else
                local t,err=CheckAndLoad("return " .. result)
                if(t) then 
                    print("Updating with downloaded content...")
                    local fname=CreateDB(t)
                    if(fname) then
                        print("Programs info updated and saved to " .. fname)
                    else
                        print("Unable to update programs info.")
                    end
                else
                    print("Failed to load downloaded content. Error: " .. err)
                end
            end
        end
    end

    return
end

if(args[1]=="install") then
    if(#args<2) then 
        print("Nothing to install.")
        return
    else
        if(not check_internet()) then return end

        print("Checking programs info...")
    end

    if(not check_db()) then return end

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
    io.write("\t")
    for this_lib in pairs(to_install) do
        io.write(this_lib .. " ")
        count_libs=count_libs+1
        for k in pairs(db[this_lib].files) do
            count_files=count_files+1
        end
    end
    print("\n" .. count_libs .. " libraries will be installed. " .. count_files .. " files will be downloaded.")

    local time_before=computer.uptime()

    print("Downloading...")
    local id_installing=0
    for this_lib in pairs(to_install) do
        for k,v in pairs(db[this_lib].files) do
            id_installing=id_installing+1

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
            local this_url
            if(db[this_lib].proxy) then
                this_url=string.gsub(
                    string.gsub(
                        string.gsub(
                            db[this_lib].proxy,
                            "__repo__",
                            db[this_lib].repo or "Kiritow/OpenComputerScripts"
                        ),
                        "__branch__",
                        db[this_lib].branch or "master"
                    ),
                    "__file__",
                    toDownload
                )
            else
                this_url=UrlGenerator(db[this_lib].repo or "Kiritow/OpenComputerScripts",db[this_lib].branch or "master",toDownload)
            end
            local ok,result,code=download(this_url)
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
    print("Fetched " .. count_files .. " files in " .. string.format("%.1f",computer.uptime()-time_before) .. " seconds.")
    if(not options["skip_install"]) then
        print("Installing...")
        for this_lib in pairs(to_install) do
            if(db[this_lib].installer) then
                print("Running installer for " .. this_lib .. "...")
                local fn,err=loadfile(db[this_lib].installer)
                if(not fn) then
                    print("[Installer Error]: " .. err)
                else
                    local ok,xerr=pcall(fn)
                    if(not ok) then
                        print("[Installer Error]: " .. xerr)
                    end
                end
            end
        end
    else
        print("Installing is skipped.")
    end
    print("Installed " .. count_libs .. " libraies with " .. count_files .. " files.")
    return
end

if(args[1]=="list") then
    if(not check_db()) then return end

    print("Listing projects...")
    for this_lib in pairs(db) do
        print(this_lib)
    end

    return
end

if(args[1]=="search") then
    if(not check_db()) then return end
    if(#args<2) then
        print("Nothing to search.")
        return
    end

    print("Libraries matches '" .. args[2] .. "' :")
    for this_lib in pairs(db) do
        if(string.match(this_lib,args[2])) then
            print(this_lib)
        end
    end

    return
end

if(args[1]=="show") then
    if(not check_db()) then return end
    if(#args<2) then
        print("Nothing to show.")
    end

    if(db[args[2]]) then
        local this_info=db[args[2]]
        print("Name: " .. args[2])
        if(this_info.deprecated) then 
            print("Title: [Deprecated] " .. this_info.title)
        else
            print("Title: " .. this_info.title)
        end
        print("Info: " .. this_info.info)
        if(this_info.author) then print("Author: " .. this_info.author) end
        if(this_info.contact) then print("Contact: " .. this_info.contact) end

        local nFiles=0
        for k,v in pairs(this_info.files) do nFiles=nFiles+1 end
        print("Files: " .. nFiles)

        if(this_info.precheck) then print("Precheck: Yes") end
        if(this_info.installer) then print("Installer: Yes") end
    else
        print("Library " .. args[2] .. " not found.")
    end

    return
end

if(args[1]=="download") then
    if(#args<2) then
        print("Nothing to download.")
        return
    else
        if(not check_internet()) then return end
        print("Collecting files...")
    end

    local files={}
    for i=2,#args,1 do 
        table.insert(files,args[i])
    end

    for i=1,#files,1 do
        io.write("[" .. i .. "/" .. #files .. "] Downloading " .. files[i] .. "...")
        local ok,result,code=download(UrlGenerator("Kiritow/OpenComputerScripts","master",files[i]))
        if(not ok) then 
            print("[Download Failed] " .. result)
            return
        elseif(code~=200) then
            print("[Download Failed] response code " .. code .. " is not 200.")
            return 
        else
            local f,ferr=io.open(files[i],"w")
            if(not f) then
                print("[Write Failed] Unable to write. Error:" .. ferr)
            else
                f:write(result)
                f:close()
                print("[OK]")
            end
        end
    end

    return
end


-- reach here? 
if(#args<1) then
    show_usage()
else
    print("Unknown command: " .. args[1])
end