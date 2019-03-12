local component=require("component")

local function Download(url,param)
    param = param or {}
    local device=param["device"] or component.internet
    if(device==nil) then
        error("The downloader requires an Internet card.")
    end
    local handle=device.request(url)
    while true do
        local ret,err=handle.finishConnect()
        if(ret==nil) then
            return false,err
        elseif(ret) then
            break
        end
        if(param["dosleep"]) then
            os.sleep(type(param["dosleep"]=="number") and param["dosleep"] or 0.05)
        end
    end
    local code,msg,headers=handle.response()
    if(param["onresponse"]) then
        if(param["onresponse"](code,msg,headers)) then
            handle.close()
            return false,"terminated by onresponse callback."
        end
    end
    local ans=''
    while true do
        local tmp=handle.read(type(param["readBuff"])=="number" and param["readBuff"] or 10240)
        if(tmp==nil) then break
        elseif(tmp~='') then
            if(param["ondata"]) then
                param["ondata"](tmp)
            else
                ans=ans .. tmp
            end
        end
    end
    handle.close()

    return true,ans,code
end

return {
    ["download"]=Download
}
