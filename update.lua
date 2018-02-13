---------------------------- Begin of From Downloader

local component=require("component")

local function doRealDownload(url)
    local hwtable=component.list("internet")
    local found=false
    for k,v in pairs(hwtable) do
        found=true
    end
    if(not found) then
        error("The downloader requires an Internet card.")
    end

    local handle=component.internet.request(url)

    local ans=""
    while true do
        local tmp=handle.read()
        if(tmp==nil) then break end
        ans=ans .. tmp
    end
    handle.close()

    return ans
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

local code_lst=
{
    "SignReader",
    "checkarg",
    "class",
    -- "downloader",
    "libevent",
    "libnetwork",
    -- "mcssh",
    "queue",
    "util",
    "vector"
}

local cnt_all=0
for k,v in pairs(code_lst) do
    cnt_all=cnt_all+1
end

local cnt_now=1

-- Download from the list
for k,v in pairs(code_lst) do 
    print("Updating (" .. cnt_now .. "/" .. cnt_all .. "): " .. v)
    local x=DownloadFromOCS(v .. ".lua")
    if(x~=nil) then WriteStringToFile(x,v .. ".lua") end
    cnt_now = cnt_now + 1
end