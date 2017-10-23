local component=require("component")

function DownloadFromGitHub(RepoName,Branch,FileAddress)
    local hwtable=component.list()
    local found=false
    for k,v in pairs(hwtable) do
        if(v=="internet") then
            found=true
        end
    end
    if(not found) then
        error("The downloader requires an Internet card.")
    end

    local url="https://raw.githubusercontent.com/" .. RepoName .. "/" .. Branch .. "/" .. FileAddress
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

