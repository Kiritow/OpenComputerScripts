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