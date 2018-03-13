---------------------------- Begin of From Downloader

local component=require("component")

local function doRealDownload(url)
    if(component.internet==nil) then
        error("The downloader requires an Internet card.")
    end

    local handle=component.internet.request(url)

    while true do
        local ret,err=handle.finishConnect()
        if(ret==nil) then
            return false,err
        elseif(ret==true) then
            break
        end
        --os.sleep(0.1)
    end

    local response_code=handle.response()

    local ans=""
    while true do
        local tmp=handle.read()
        if(tmp==nil) then break end
        ans=ans .. tmp
    end
    handle.close()

    return true,ans,response_code
end

function DownloadFromGitHub(RepoName,Branch,FileAddress)
    local url="https://raw.githubusercontent.com/" .. RepoName .. "/" .. Branch .. "/" .. FileAddress
    return doRealDownload(url)
end

function DownloadFromOCS(FileAddress)
    return DownloadFromGitHub("Kiritow/OpenComputerScripts","master",FileAddress)
end

function WriteStringToFile(StringValue,FileName,IsAppend)
    if(IsAppend==nil) then IsAppend=false end
    local handle,err
    if(IsAppend) then 
        handle,err=io.open(FileName,"a")
    else
        handle,err=io.open(FileName,"w")
    end
    if(handle==nil) then return false,err end

    handle:write(StringValue)
    handle:close()

    return true,"Success"
end

----------------------------- End of From Downloader
local shell=require("shell")
local args=shell.parse(...)
local argc=#args

local file_lst={}

if(argc<1) then
file_lst=
{
    "SignReader.lua",
    "checkarg.lua",
    "class.lua",
    "downloader.lua",
    "libevent.lua",
    "queue.lua",
    "util.lua",
    "vector.lua",
    "LICENSE"
}
else
    for i=1,argc,1 do
        table.insert(file_lst,args[i])
    end
end

local cnt_all=0
for k,v in pairs(file_lst) do
    cnt_all=cnt_all+1
end

local cnt_now=1

-- Download from the list
for k,v in pairs(file_lst) do 
    io.write("Updating (" .. cnt_now .. "/" .. cnt_all .. "): " .. v .. " ")
    local flag,x,y=DownloadFromOCS(v)
    if((not flag) or (y~=200) ) then
        print("[Download Failed]")
    else
        local ret=WriteStringToFile(x,v)
        if(not ret) then
            print("[Write Failed]")
        else
            print("[OK]")
        end
        cnt_now = cnt_now + 1
    end
end