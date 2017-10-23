require("downloader")

local code_lst=
{
    "SignReader",
    "checkarg",
    "class",
    -- "downloader"
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