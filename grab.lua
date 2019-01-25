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

local grab_version="Grab v2.5.1-alpha"
local grab_infos={
    version=grab_version,
    grab_options=options
}

local usage_text=[===[Grab - Official OpenComputerScripts Installer
Usage:
    grab [<options>] <command> ...
Options:
    --cn Skip link check and use mirror site in China. See Link check in Notice for more information.
    --help Display this help page.
    --version Display version and exit.
    --router=<Router File> [Deprecated] Given a file which will be loaded and returns a route function like:
        function(RepoName: string, Branch: string ,FileAddress: string): string
    --proxy=<Proxy File> Given a file which will be loaded and returns a proxy function like:
        function(Url : string): boolean, string
    --bin=<path> Set binary install root path.
    --lib=<path> Set library install root path.
    -f,--force Force overwrite existing files.
    -y,--yes Skip interactive confirm.
    --skip-install Library installers will not be executed.
    --refuse-license <License> Set refused license. Separate multiple values with ','
    --accept-license <License> Set accepted license. Separate multiple values with ','
Command:
    install <Project> ...: Install projects. Dependency will be installed automatically.
    uninstall <Project> ...: Uninstall projects. Dependency will NOT be removed automatically.
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
    Router and Proxy
        [Deprecated] route_func(RepoName: string, Branch: string ,FileAddress: string): string
            A route function takes repo, branch and file address as arguments, and returns a resolved url.
            It can be used to boost downloading by redirecting requests to mirror site.
            As router functions can be used to redirect requests, Grab will give an warning if --router option presents.
            [Warning] --router option is deprecated and will be removed in future.
        proxy_func(Url : string): boolean, string
            A proxy function takes url as argument, and returns at least 2 values.
            It can be used to handle different protocols or low-level network operations like downloading files via SOCKS5 proxy or in-game modem network.
            The first returned value is true if content is downloaded successfully. Thus, the second value will be the downloaded content.
            If the first value is false, the downloading is failed. The second value will then be the error message.
            If proxy functions throw an error, Grab will try the default downloader.
    Installer
        A package can provide an installer for Grab. It will be loaded and executed after the package is ready.
        Thus require(...) calls on depended libraries is ok.
        From Grab v2.4.6, installer should return a function, which will be later called with a table filled with some information.
        If nothing is returned, Grab will give an warning and ignore it.
        From Grab v2.4.8, option `installer` is deprecated. Use __installer__ instead.
    Link Check
        Grab will perform a link check before downloading anything. The link check will choose to download from Github or mirror site in China.
        This might only be useful for official packages.
]===]

-- Install man document.
local function _local_install()
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
end
if(not filesystem.exists("/etc/grab/grab.version")) then
    _local_install()
else
    local f=io.open("/etc/grab/grab.version","r")
    if(f) then
        local installed_version=f:read("a")
        f:close()
        if(installed_version~=grab_version) then
            _local_install()
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
    ["router"]="string",
    ["proxy"]="string", 
    ["bin"]="string",
    ["lib"]="string",
    ["f"]=true,
    ["force"]=true,
    ["y"]=true,
    ["yes"]=true,
    ["skip-install"]=true, 
    ["refuse-license"]=true,
    ["accept-license"]=true,
}
local valid_command={
    ["install"]=true,
    ["uninstall"]=true,
    ["verify"]=true,
    ["add"]=true,
    ["update"]=true,
    ["clear"]=true,
    ["list"]=true,
    ["search"]=true,
    ["show"]=true,
    ["download"]=true
}

for k,v in pairs(options) do 
    if(not valid_options[k]) then 
        if(string.len(k)>1) then
            print("Unknown option: --" .. k)
        else
            print("Unknown option: -" .. k) 
        end
        return
    elseif(type(valid_options[k])=="string") then
        if(type(options[k])~=valid_options[k]) then
            print("Invalid option type: Option type of --" .. k .. " should be " .. valid_options[k])
            return
        end
    end
end

if( #args<1 and not next(options) ) then
    print("grab: try 'grab --help' for more information.")
    return
end

if(options["help"]) then
    show_usage()
    return
end

if(options["version"]) then
    print(grab_version)
    return
end

local function optionYes()
    return options["y"] or options["yes"]
end

local function optionForce()
    return options["f"] or options["force"]
end

local function check_internet()
    if(not options["proxy"] and not component.list("internet")()) then
        print("Error: An internet card is required to run this program.")
        return false
    else
        -- If proxy presents, internet card is not required. Programs may handle network requests via in-game modem network.
        return true
    end
end

local function default_downloader(url)
    if(not component.list("internet")()) then
        return false,"No internet card found."
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
    if(code~=200) then
        handle.close()
        return false,"Response code " .. code .. " is not 200."
    end

    local result=''
    while true do 
        local temp=handle.read()
        if(temp==nil) then break end
        result=result .. temp
    end

    handle.close()
    return true,result
end

local download
if(not options["proxy"]) then
    download=default_downloader
else
    local ok,err=pcall(function()
        local fn,xerr=loadfile(options["proxy"])
        if(not fn) then 
            error(xerr) 
        else 
            tmp=fn()
            if(type(tmp)~="function") then
                error("Loaded proxy returns " .. type(tmp) .. " instead of a function.")
            end
            download=function(url)
                local pok,ok,data=pcall(tmp,url)
                if(pok) then 
                    return ok,data
                else
                    return default_downloader(url)
                end
            end
        end
    end)
    if(not ok) then
        print("Unable to load proxy file: " .. err)
        return
    end

    print("[WARN] Proxy presents. Be aware of security issues.")
end

local function link_check()
    local ok,data=download("http://registry.kiritow.com/gateway")
    if(ok and data=="CN") then
        return true
    else
        return false
    end
end

local function _MirrorUrlGen(RepoName,Branch,FileAddress)
    return "http://kiritow.com:3000/" .. RepoName .. "/raw/" .. Branch .. "/" .. FileAddress
end
local function _GithubUrlGen(RepoName,Branch,FileAddress)
    return "https://raw.githubusercontent.com/" .. RepoName .. "/" .. Branch .. "/" .. FileAddress
end

local UrlGenerator
if(not options["router"]) then
    if(options["cn"] or link_check()) then
        UrlGenerator=_MirrorUrlGen
    else
        UrlGenerator=_GithubUrlGen
    end
else
    print("[WARN] --router option is deprecated and will be removed in future.")
    local ok,err=pcall(function()
        local fn,xerr=loadfile(options["router"])
        if(not fn) then 
            error(xerr) 
        else 
            UrlGenerator=fn()
            if(type(UrlGenerator)~="function") then
                error("Loaded router returns " .. type(UrlGenerator) .. " instead of a function.")
            end
        end
    end)
    if(not ok) then
        print("Unable to load router file: " .. err)
        return
    end

    print("[WARN] Router presents. Be aware of security issues.")
end

local function IsOfficial(tb_package)
    if(tb_package.repo==nil and 
        tb_package.proxy==nil and 
        tb_package.provider==nil
    ) then
        return true
    else
        return false
    end
end

local grab_dir=''

local function CheckGrabDir()
    local locations={"/etc/grab","/home/.grab","/tmp/.grab"}
    for idx,position in ipairs(locations) do
        if(filesystem.isDirectory(position)) then
            grab_dir=position
            return true
        else
            local ok=filesystem.makeDirectory(position)
            if(ok) then grab_dir=position return true end
        end
    end
    return false
end
if(not CheckGrabDir()) then
    print("[Error] Grab working directory not usable.")
    return
else
    print("Grab directory: " .. grab_dir)
end

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
                if(type(vv)=="table") then
                    for idx,val in pairs(vv) do
                        if(type(idx)~="number" or type(val)~="string") then
                            return false,"Library " .. k .. " file " .. kk .. " table has invalid key,value type: " .. type(idx) .. "," .. type(val)
                        end
                    end
                elseif(type(vv)~="string") then
                    return false,"Library " .. k .. " file " .. kk .. " has invalid value type " .. type(vv)
                end
            else
                return false,"Library " .. k .. " file has invalid key type " .. type(kk)
            end
        end

        if(t.author and type(t.author)~="string") then
            return false,"Library " .. k .. " has invalid author type: " .. type(t.author)
        end

        if(t.contact and type(t.contact)~="string") then
            return false,"Library " .. k .. " has invalid contact type: " .. type(t.contact)
        end

        if(t.requires) then
            for kk,vv in pairs(t.requires) do
                if(type(kk)~="number" or type(vv)~="string") then
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
        if(t.provider) then
            if(type(t.provider)~="string") then
                return false,"Library " .. k .. " has invalid provider type " .. type(t.provider)
            end
        end
        if(t.hidden~=nil) then
            if(type(t.hidden)~="boolean") then
                return false,"Library " .. k .. " has invalid hidden type " .. type(t.hidden)
            end
        end
    end

    return true,"No error detected."
end

local function CheckAndLoadEx(raw_content,chunkname)
    local fn,err=load(raw_content,chunkname)
    if(fn) then 
        local ok,result=pcall(fn)
        if(ok) then
            return result
        else return nil,result end
    end
    return nil,err
end

local function CheckAndLoad(raw_content,chunkname)
    local result,err=CheckAndLoadEx(raw_content,chunkname)
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

    local filename=grab_dir .. "/programs.info"
    local a,b=ReadDB(filename)
    if(a) then return a,b end

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
    local filename=grab_dir .. "/programs.info"
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

if(args[1]=="clear") then
    print("Clearing programs info...")
    filesystem.remove(grab_dir .. "/programs.info")
    print("Programs info cleaned. You may want to run `grab update` now.")
    return 
end

if(args[1]=="update") then
    if(not check_internet()) then return end

    print("Updating programs info....")
    io.write("Downloading... ")
    local ok,result=download(UrlGenerator("Kiritow/OpenComputerScripts","master","programs.info"))
    if(not ok) then
        print("[Failed] " .. result)
    else
        print("[OK]")
        io.write("Validating... ")
        local tb_data,validate_err=CheckAndLoad("return " .. result,"Remote ProgramDB")
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

local function pairsKey(tb)
    local tmp={}
    for k in pairs(tb) do table.insert(tmp,k) end
    table.sort(tmp)
    local i=0
    return function()
        i=i+1
        return tmp[i],tb[tmp[i]]
    end,tb,nil
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
                local t,err=CheckAndLoad("return " .. content,"Local ProgramDB")
                if(t) then 
                    print("[Verified] Contains the following library: ")
                    for k in pairsKey(t) do
                        print(k)
                    end
                else
                    print("Failed to load local file: " .. filename .. ". Error: " .. err)
                end
            end
        else
            print("Downloading from " .. url)
            local ok,result=download(url)
            if(not ok) then
                print("[Download Failed] " .. result)
            else
                local t,err=CheckAndLoad("return " .. result,"Remote ProgramDB")
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
                local t,err=CheckAndLoad("return " .. content,"Local ProgramDB")
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
            local ok,result=download(url)
            if(not ok) then
                print("[Download Failed] " .. result)
            else
                local t,err=CheckAndLoad("return " .. result,"Remote ProgramDB")
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

local function getshowspeed(n)
    if(n<1024) then
        return string.format("%.1f B/s",n+0.0)
    elseif(n<1024*1024) then
        return string.format("%.1f KB/s",n/1024)
    else
        return string.format("%.1f MB/s",n/1024/1024)
    end
end

local function try_resolve_path(src,dst,only_parse)
    -- TIPS:
    -- filesystem.makeDirectory(...) can throw error because it does not check arguments.
    local fsMakeDir
    if(not only_parse) then
        fsMakeDir=filesystem.makeDirectory
    else
        fsMakeDir=function() return true end
    end

    if(type(src)~="string") then -- Only source path is specified in programs.info
        local segs=filesystem.segments(dst)
        return true,segs[#segs]
    end

    dst=string.gsub(
        string.gsub(
            dst,
            "__bin__",
            options["bin"] or "/usr/bin"
        ),
        "__lib__",
        options["lib"] or "/usr/lib"
    )

    if(dst:sub(dst:len())=='/') then -- dst is a directory. prepare it and build the filename.
        if(not fsMakeDir(dst) and not filesystem.exists(dst)) then
            return false,"Failed to create directory: " .. dst
        else
            local tb_segsrc=filesystem.segments(src)
            return true,dst .. tb_segsrc[#tb_segsrc]
        end
    else -- dst is the filename. Prepare directories.
        local tb_segdst=filesystem.segments(dst)
        if(#tb_segdst>1) then
            local name=table.concat(tb_segdst,"/",1,#tb_segdst-1)
            if(not fsMakeDir(name) and not filesystem.exists(name)) then
                return false,"Failed to create directory: " .. name
            end
        end

        return true,dst
    end
end

local function string_similar_value(a,b)
    local x,y=a:len(),b:len()
    local min=( (x>y) and y or x)
    local c=0
    for i=1,min do
        if(a:sub(i,i)==b:sub(i,i)) then
            c=c+1
        end
    end
    return c
end

local function miss_suggestion(wrong_name,ktb)
    local max=0
    local maxname=nil
    for this_lib in pairs(ktb) do
        local a=string_similar_value(wrong_name,this_lib)
        if(a>max) then
            max=a
            maxname=this_lib
        end
    end
    return maxname,max
end

local function will_overwrite(filename)
    if(optionForce()) then 
        return false
    else
        local f=io.open(filename,"rb")
        if(f) then
            f:close()
            print("[Error] Stop before overwrite regular file: " .. filename)
            return true
        else
            return false
        end
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

    if(optionForce()) then
        print("[WARN] Using force mode. I sure hope you know what you are doing.")
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
                local maybe_this=miss_suggestion(this_lib,db)
                if(maybe_this) then
                    print("You might want library '" .. maybe_this .. "'.")
                end
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

    print("About to install the following libraries:")
    local count_libs=0
    local count_files=0
    io.write("\t")
    for this_lib in pairsKey(to_install) do
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

    -- If more libraries will be installed or unofficial libraries present, pop up a confirm.
    if(not optionYes() and (count_libs>#args-1 or next(warn_libs_unofficial))) then
        io.write("Do you want to continue? [Y/n]: ")
        local line=io.read("l")
        if(not (line:len()<1 or line:sub(1,1)=="Y" or line:sub(1,1)=="y")) then
            print("Aborted.")
            return
        end
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
                local ok,result=download(db[this_lib].license.url)
                if(not ok) then
                    print("[Download Failed] Failed to download license.")
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

                filesystem.remove(temp_name)

                if(confirmed==2) then
                    print("[License Refused] License " .. db[this_lib].license.name .. " for library " .. this_lib .. " is refused by user.")
                    return
                else
                    print("Accepted license " .. db[this_lib].license.name .. " for library " .. this_lib)
                end
            end
        end
    end

    print("Downloading...")
    local count_byte=0
    local id_installing=0
    local time_before=computer.uptime()
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
            local ok,result=download(this_url)
            if(not ok) then 
                print("[Download Failed] " .. result)
                return
            else
                count_byte=count_byte+string.len(result)
                
                if(type(v)=="string") then
                    local toSave
                    if(v=="__installer__") then
                        toSave=os.tmpname()
                        to_install[this_lib]=toSave
                    else
                        toSave=v
                    end

                    local ok,fname=try_resolve_path(k,toSave)
                    if(not ok) then
                        print("[Error] " .. fname)
                        return
                    end

                    if(will_overwrite(fname)) then
                        return
                    end

                    local f=io.open(fname,"wb")
                    if(not f) then
                        print("[Error] Failed to open file " .. fname .. " for writing.")
                        return
                    else
                        local ok,err=f:write(result)
                        f:close()
                        if(not ok) then
                            print("[Error] Failed while writing to file: " .. fname .. ": " .. err)
                            return
                        end
                    end
                elseif(type(v)=="table") then
                    local done=false
                    
                    for idx,this_name in ipairs(v) do
                        local ok,fname=try_resolve_path(k,this_name)
                        if(ok) then
                            if(will_overwrite(fname)) then
                                return
                            end

                            local f=io.open(fname,"wb")
                            if(f) then
                                local ok,err=f:write(result)
                                f:close()
                                if(not ok) then
                                    print("[Error] Failed while writing to file: " .. fname .. ": " .. err)
                                    return
                                end

                                done=true
                                break
                            end
                        end
                    end

                    if(not done) then
                        print("[Error] Unable to save file: " .. toDownload)
                        return
                    end
                else
                    print("[Error] Invalid program info value type: " .. type(v))
                    return
                end

                -- [OK]
                print("[" .. getshowbyte(string.len(result)) .. "]")
            end
        end
    end
    local time_diff=computer.uptime()-time_before
    print("Fetched " .. count_files .. " files (" 
        .. getshowbyte(count_byte) .. ") in "
        .. getshowtime(time_diff)
        .. " (" .. getshowspeed(count_byte/time_diff) .. ")"
    )
    if(not options["skip-install"]) then
        print("Installing...")
        local has_installed={}
        local recursion_detect={}
        local function do_install_dfs(this_lib)
            if(recursion_detect[this_lib] or has_installed[this_lib]) then
                return true
            end
            recursion_detect[this_lib]=true

            if(db[this_lib].requires) then
                for idx,req_lib in ipairs(db[this_lib].requires) do
                    if(not do_install_dfs(req_lib)) then -- Deeper Failure
                        return false
                    end
                end
            end

            local this_installer
            if(type(to_install[this_lib])=="string") then
                this_installer=to_install[this_lib]
            elseif(db[this_lib].installer) then
                print("[WARN] From Grab v2.4.8, option `installer` is deprecated. Use __installer__ instead.")
                this_installer=db[this_lib].installer
            else
                -- No Installer: Mark as installed.
                has_installed[this_lib]=true
                recursion_detect[this_lib]=nil
                return true
            end

            print("Running installer for " .. this_lib .. "...")
            local fn,err=loadfile(this_installer)
            if(not fn) then
                print("[Installer Error]: " .. err)
            else
                local ok,xerr=pcall(fn)
                if(not ok) then
                    print("[Installer Error]: " .. xerr)
                elseif(type(xerr)=="function") then
                    if(not pcall(xerr,grab_infos)) then
                        print("[Installer Error]: " .. xerr)
                    else
                        has_installed[this_lib]=true
                        done=true
                    end
                else
                    print("[Warn]: From Grab v2.4.6, installers should return functions.")
                    done=true
                end
            end

            if(type(this_value)=="string") then -- This might be skipped?
                filesystem.remove(this_installer)
            end

            recursion_detect[this_lib]=nil
            return done
        end -- end of local function do_install_dfs(...)

        for this_lib in pairs(to_install) do
            if(not do_install_dfs(this_lib)) then
                print("Failed to install some library. Installation aborted.")
                return
            end
        end
    else
        print("Installation is skipped.")
    end
    print("Installed " .. count_libs .. " libraies with " .. count_files .. " files.")
    return
end

if(args[1]=="uninstall") then
    if(not check_db()) then return end
    if(#args<2) then
        print("Nothing to uninstall.")
        return
    end

    print("Checking programs info...")

    if(optionForce()) then
        print("[WARN] Using force mode. I sure hope you know what you are doing.")
    end

    local to_uninstall={}
    for i=2,#args do
        to_uninstall[args[i]]={}
    end

    local count_byte=0
    for this_lib,this_files in pairs(to_uninstall) do
        if(not db[this_lib]) then
            print("Library '" .. this_lib .. "' not found.")
            local maybe_this=miss_suggestion(this_lib,db)
            if(maybe_this) then
                print("Do you mean '" .. maybe_this .. "'")
            end
            return
        else
            for k,v in pairs(db[this_lib].files) do
                if(v~="__installer__") then -- Skip the installer
                    local ok,filename=try_resolve_path(k,v,true)
                    if(not ok) then
                        print("[Resolve Error] " .. filename)
                        return
                    end
                    if(filename.sub(1,5)~="/tmp/") then -- Files in /tmp/ are not checked and will not be removed by uninstall.
                        if(not optionForce() and not filesystem.exists(filename)) then
                            print("[Error] Library " .. this_lib .. " check failed.")
                            print("[Error] Missing file: " .. filename)
                            print("[Error] Library might be corrupted or missing. Try reinstall it or uninstall it in force mode.")
                            return
                        end
                    end
                    count_byte=count_byte+filesystem.size(filename)
                    table.insert(this_files,filename)
                end
            end
        end
    end

    print("About to uninstall the following libraries:")
    local count_libs=0
    local count_files=0
    io.write("\t")
    for this_lib,this_files in pairsKey(to_uninstall) do
        io.write(this_lib .. " ")
        count_libs=count_libs+1
        count_files=count_files+#this_files
    end
    print("\n" .. count_libs .. " libraries will be uninstalled. " .. count_files .. " files will be removed. " .. getshowbyte(count_byte) .. " disk space will be freed.")

    print("Removing...")
    local id_current=0
    for this_lib,this_files in pairs(to_uninstall) do
        for k,filename in pairs(this_files) do
            id_current=id_current+1
            io.write("[" .. id_current .. "/" .. count_files .. "] Deleting " .. filename .. " for " .. this_lib .. "... ")
            
            local ok,err=filesystem.remove(filename)
            if(not ok) then
                if(not optionForce()) then
                    print("[Failed] " .. err)
                    return
                else
                    print("[Skipped] " .. err)
                end
            else
                print("[OK]")
            end
        end
    end

    print("Removed " .. count_libs .. " libraries. " .. getshowbyte(count_byte) .. " disk space freed.")
    return
end


if(args[1]=="list") then
    if(not check_db()) then return end

    print("Listing projects...")
    for this_lib in pairsKey(db) do
        if(not db[this_lib].hidden) then
            print(this_lib)
        end
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
    for this_lib in pairsKey(db) do
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
        if(this_info.hidden) then print("Hidden: Yes") end
        if(this_info.provider) then print("Provider: " .. this_info.provider) end

        if(this_info.license) then
            print("License: " .. this_info.license.name)
        end
    else
        print("Library " .. args[2] .. " not found.")
        local maybe_this=miss_suggestion(this_lib,db)
        if(maybe_this) then
            print("You might want library '" .. maybe_this .. "'.")
        end
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
        local ok,result=download(UrlGenerator("Kiritow/OpenComputerScripts","master",files[i]))
        if(not ok) then 
            print("[Download Failed] " .. result)
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
    local maybe_this=miss_suggestion(args[1],valid_command)
    if(maybe_this) then
        print("Do you mean '" .. maybe_this .. "' ?")
    end
end