-- Grab : Official OpenComputerScripts Installer
-- Created By Kiritow
local computer=require('computer')
local component=require('component')
local shell=require('shell')
local filesystem=require('filesystem')
local serialization=require('serialization')
local event=require('event')
local term=require('term')
local args,options=shell.parse(...)

local grab_version="Grab v2.4.2-alpha"

local usage_text=[===[Grab - Official OpenComputerScripts Installer
Usage:
    grab [<options>] <command> ...
Options:
    --cn Use mirror site in China. By default grab will download from Github. This might be useful for only official packages.
    --help Display this help page.
    --version Display version and exit.
    --proxy=<Proxy File> Given a proxy file which will be loaded and returns a proxy function like:
        function(RepoName: string, Branch: string ,FileAddress: string): string
    --skip-install Library installers will not be executed.
    --refuse-license <License> Set refused license. Separate multiple values with ','
    --accept-license <License> Set accepted license. Separate multiple values with ','
Command:
    install <Project> ...: Install projects. Dependency will be downloaded automatically.
    verify <Provider> ... : Verify program provider info.
    add <Provider> ... : Add program provider info.
    update: Update program info.
    clear: Clear program info.
    list: List available projects.
    search <Name or Pattern> :  Search projects by name
    show <Project> : Show more info about project.
    download <Filename> ...: Directly download files. (Just like the old `update`!)
Notice:
    License
        By downloading and using Grab, you are indicating your agreement to MIT license. (https://github.com/Kiritow/OpenComputerScripts/blob/master/LICENSE)
        All scripts in official OpenComputerScript repository are under MIT license.
        Before downloading any package under other licenses, Grab will ask you to agree with it.
        This confirmation can be skipped by calling Grab with --accept-license.
        Example:
            --accept-license=mit means MIT License is accepted. 
            --refuse-license=mit means MIT License is refused. 
            --accept-license means all licenses are accepted.
            --refuse-license means all licenses are refused. (Official packages are not affected.)
            If a license is both accepted and refused, it will be refused.
    Program Provider
        A package is considered to be official only if it does not specified repo and proxy. Official packages usually only depend on official packages.
        You can also install packages from unofficial program provider with Grab, but Grab will not check its security.
        Notice that override of official packages is not allowed.
]===]

-- Install man document
if(not filesystem.exists("/etc/grab/grab.version")) then
    local f=io.open("/etc/grab/grab.version","w")
    if(f) then
        f:write(grab_version)
        f:close()
    end
    f=io.open("/usr/man/grab","w")
    if(f) then
        f:write(usage_text)
        f:close()
    end
else
    local f=io.open("/etc/grab/grab.version","r")
    if(f) then
        local installed_version=f:read("a")
        f:close()
        if(installed_version~=grab_version) then
            f=io.open("/usr/man/grab","w")
            if(f) then
                f:write(usage_text)
                f:close()
            end
        end
    end
end

local function show_usage()
    if(filesystem.exists("/usr/man/grab")) then
        os.execute("less /usr/man/grab")
    else
        local temp_name=os.tmpname()
        local f=io.open(temp_name,"w")
        f:write(usage_text)
        f:close()
        os.execute("less " ..  temp_name)
        os.execute("rm " .. temp_name)
    end
end

local valid_options={
    ["cn"]=true, 
    ["help"]=true, 
    ["version"]=true, 
    ["proxy"]=true, 
    ["skip-install"]=true, 
    ["refuse-license"]=true,
    ["accept-license"]=true
}
local valid_command={
    ["install"]=true,
    ["verify"]=true,
    ["add"]=true,
    ["update"]=true,
    ["clear"]=true,
    ["list"]=true,
    ["search"]=true,
    ["show"]=true,
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
            local ev=event.pull(0.05,"interrupted")
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

local function IsOfficial(tb_package)
    if(tb_package.repo==nil and tb_package.proxy==nil) then
        return true
    else
        return false
    end
end

local db_dirs={"/etc/grab",".grab","/tmp/.grab"}
local db_positions={"/etc/grab/programs.info",".grab/programs.info","/tmp/.grab/programs.info"}

local function VerifyDB(this_db)
    for k,t in pairs(this_db) do
        if(type(k)~="string") then
            return false,"Invalid key type: " .. type(k)
        elseif(type(t)~="table") then
            return false,"Invalid value type: " .. type(t)
        elseif(not t.title) then
            return false,"Library " .. k .. " does not provide title."
        elseif(not t.info) then
            return false,"Library " .. k .. " does not provide info."
        elseif(not t.files) then
            return false,"Library " .. k .. " has no file."
        end

        for kk,vv in pairs(t.files) do
            if(type(kk)=="number") then
                if(type(vv)~="string") then
                    return false,"Library " .. k .. " file " .. kk .. " has invalid value type " .. type(vv)
                end
            elseif(type(kk)=="string") then
                if(type(vv)~="string" and type(vv)~="table") then
                    return false,"Library " .. k .. " file " .. kk .. " has invalid value type " .. type(vv)
                end
            else
                return fale,"Library " .. k .. " file has invalid key type " .. type(kk)
            end
        end
        if(t.requires) then
            for kk,vv in pairs(t.requires) do
                if(type(kk)~="number" and type(vv)~="string") then
                    return false,"Library " .. k .. " has invalid requires with key type " .. type(kk) .. ", value type " .. type(vv)
                end
            end
        end
        if(t.license) then
            if(type(t.license.name)~="string") then
                return false,"Library " .. k .. " has invalid license name type " .. type(t.license.name)
            elseif(type(t.license.url)~="string") then
                return false,"Library " .. k .. " has invalid license url type " .. type(t.license.url)
            end
        end
    end

    return true,"No error detected."
end

local function CheckAndLoadEx(raw_content)
    local fn,err=load(raw_content)
    if(fn) then 
        local ok,result=pcall(fn)
        if(ok) then
            return result
        else return nil,result end
    end
    return nil,err
end

local function CheckAndLoad(raw_content)
    local result,err=CheckAndLoadEx(raw_content)
    if(not result) then
        return result,err
    end
    local ok,err=VerifyDB(result)
    if(not ok) then
        return nil,err
    else
        return result
    end
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

local function UpdateDB(main_tb,new_tb,checked) -- Change values with same key in main_tb to values in new_tb. Add new items to main_tb
    for k,v in pairs(new_tb) do
        if(checked and main_tb[k]) then
            if(IsOfficial(main_tb[k])) then
                print("UpdateDB: Attempted to override official library: " .. k)
                return false
            else
                print("UpdateDB: Override library: " .. k)
            end
        end
        main_tb[k]=v
    end
    return true
end

local function CreateDB(tb,checked) -- If checked, merging is not allowed.
    for idx,dirname in ipairs(db_dirs) do
        filesystem.makeDirectory(dirname) -- buggy
    end
    for idx,filename in ipairs(db_positions) do
        local main_db=ReadDB(filename)
        if(main_db) then
            if(not UpdateDB(main_db,tb,checked)) then
                return nil
            end
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
            local dbfilename=CreateDB(tb_data,false)
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

if(args[1]=="verify") then
    if(#args<2) then
        print("Nothing to verify.")
        return
    end

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
                    print("[Verified] Contains the following library: ")
                    for k in pairs(t) do
                        print(k)
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
                    print("[Verified] Contains the following library: ")
                    for k in pairs(t) do
                        print(k)
                    end
                else
                    print("Failed to load downloaded content. Error: " .. err)
                end
            end
        end
    end

    return
end

if(args[1]=="add") then 
    if(#args<2) then 
        print("Nothing to add.")
        return
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
                    local fname=CreateDB(t,true)
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
                    local fname=CreateDB(t,true)
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

local function getshowbyte(n)
    if(n<1024) then
        return string.format("%.1f B",n+0.0)
    elseif(n<1024*1024) then
        return string.format("%.1f KB",n/1024)
    else
        return string.format("%.1f MB",n/1024/1024)
    end
end

local function getshowtime(n)
    if(n<60) then
        return string.format("%.1fs",n+0.0)
    else
        return string.format("%.0fm%.0fs",n/3600,n%3600)
    end
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

    local warn_libs_unofficial={}
    for this_lib in pairs(to_install) do
        if(not IsOfficial(db[this_lib])) then
            table.insert(warn_libs_unofficial,this_lib)
        end
    end

    if(next(warn_libs_unofficial)) then
        print("[WARN] The following libraries are unofficial. Install at your own risk.")
        print("\t" .. table.concat(warn_libs_unofficial," "))
    end

    -- Third-Party programs or unofficial programs may have license.
    print("Checking License...")
    local accepted_license={}
    local refused_license={}
    if(options["accept-license"]) then
        if(type(options["accept-license"])=="boolean") then
            accepted_license["__ALL__"]=true
        else
            local next_license=string.gmatch(options["accept-license"] .. ',',"[A-Za-z0-9]+,")
            while true do
                local this_license=next_license()
                if(not this_license) then break end
                this_license=string.lower(string.gsub(this_license,',',''))
                accepted_license[this_license]=true
            end
        end
    end

    if(options["refuse-license"]) then
        if(type(options["refuse-license"])=="boolean") then
            refused_license["__ALL__"]=true
        else
            local next_license=string.gmatch(options["refuse-license"] .. ',',"[A-Za-z0-9]+,")
            while true do
                local this_license=next_license()
                if(not this_license) then break end
                this_license=string.lower(string.gsub(this_license,',',''))
                refused_license[this_license]=true
            end
        end
    end

    for this_lib in pairs(to_install) do
        if(not IsOfficial(db[this_lib]) and db[this_lib].license) then
            if(refused_license["__ALL__"] or refused_license[string.lower(db[this_lib].license.name)]) then
                print("[License Refused] License " .. db[this_lib].license.name .. " for library " .. this_lib .. " is refused.")
                return
            elseif(accepted_license["__ALL__"] or accepted_license[string.lower(db[this_lib].license.name)]) then
                print("Accepted license " .. db[this_lib].license.name .. " for library " .. this_lib)
            else
                -- Download the license and show it to user.
                print("Downloading license " .. db[this_lib].license.name .. " for library " .. this_lib .. " from: " .. db[this_lib].license.url)
                local ok,result,code=download(db[this_lib].license.url)
                if(not ok or code~=200) then
                    print("[Download Failed] Unable to download license.")
                    return
                end

                local temp_name=os.tmpname()
                local f=io.open(temp_name,"w")
                f:write("----------Grab----------\nYou have to agree with this license for library " .. this_lib .. "\n------------------------\n\n")
                f:write(result)
                f:close()

                local confirmed=false
                while not confirmed do
                    os.execute("less " .. temp_name)
                    print("Do you agree with that license?")
                    print("(Y) - Yes. (N) - No. (A) - View it again.")
                    while true do
                        local x=io.read()
                        if(x~=nil) then
                            if(x=='y' or x=='Y') then
                                confirmed=1
                                break
                            elseif(x=='n' or x=='N') then
                                confirmed=2
                                break
                            elseif(x=='a' or x=='A') then
                                break
                            end
                        end
                    end
                end

                os.execute("rm " .. temp_name)
                if(confirmed==2) then
                    print("[License Refused] License " .. db[this_lib].license.name .. " for library " .. this_lib .. " is refused by user.")
                    return
                else
                    print("Accepted license " .. db[this_lib].license.name .. " for library " .. this_lib)
                end
            end
        end
    end

    local time_before=computer.uptime()

    print("Downloading...")
    local count_byte=0
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
                count_byte=count_byte+string.len(result)
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
                            break
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
    print("Fetched " .. count_files .. " files (" .. getshowbyte(count_byte) .. ") in " .. getshowtime(computer.uptime()-time_before) .. ".")
    if(not options["skip-install"]) then
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
        print("Installation is skipped.")
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
        return
    end

    if(db[args[2]]) then
        local this_info=db[args[2]]
        print("Name: " .. args[2])
        print("Title: " .. this_info.title)
        if(this_info.deprecated) then print("Deprecated: Yes") end
        if(IsOfficial(this_info)) then print("Type: Official")
        else print("Type: Unofficial") end
        print("Info: " .. this_info.info)
        if(this_info.author) then print("Author: " .. this_info.author) end
        if(this_info.contact) then print("Contact: " .. this_info.contact) end

        local nFiles=0
        for k,v in pairs(this_info.files) do nFiles=nFiles+1 end
        print("Files: " .. nFiles)

        if(this_info.precheck) then print("Precheck: Yes") end
        if(this_info.installer) then print("Installer: Yes") end
        if(this_info.proxy) then print("Proxy: Yes") end

        if(this_info.license) then
            print("License: " .. this_info.license.name)
        end
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