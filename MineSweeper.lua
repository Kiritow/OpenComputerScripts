-- Mine Sweeper Game
-- Author: Github/Kiritow

require("libgpu")
require("libevent")
require("queue")
local component=require("component")
local shell=require("shell")

local args=shell.parse(...)
local argc=#args

local gpu=GetGPU()

local function generateMap(line,col,all)
    local t={}
    for i=0,line+1,1 do
        t[i]={}
    end

    local cnt=0
    while(cnt<all) do
        local cl=math.random(1,line)
        local cc=math.random(1,col)
        if(t[cl][cc]==nil) then
            t[cl][cc]=-1
            cnt=cnt+1
        end
    end
    local function val(xl,xc)
        if(t[xl][xc]==nil) then return 0
        elseif(t[xl][xc]<0) then return 1
        else return 0
        end
    end
    for i=1,line,1 do
        for j=1,col,1 do
            if(t[i][j]==nil) then
                t[i][j]=val(i-1,j-1)+val(i-1,j)+val(i-1,j+1)+
                        val(i,j-1)+val(i,j+1)+
                        val(i+1,j-1)+val(i+1,j)+val(i+1,j+1)
            end
        end
    end

    t.line=line
    t.col=col
    t.all=all
    return t
end

local function debugPrintMap(t)
    gpu:clear()
    for i=1,t.line,1 do
        for j=1,t.col,1 do
            if(t[i][j]>=0) then
                gpu:set(i,j,tostring(t[i][j]))
            else
                gpu:set(i,j,"X")
            end
        end
    end
end

local function generateBlankMask(line,col,val)
    local t={}
    for i=1,line,1 do
        t[i]={}
        for j=1,col,1 do
            t[i][j]=val
        end
    end
    t.line=line
    t.col=col
    return t
end

local function printMap(base,mask)
    gpu:clear()
    for i=1,base.col+2,1 do
        gpu:set(1,i,"-")
    end

    for i=1,base.line,1 do
        gpu:set(i+1,1,"|")

        for j=1,base.col,1 do 
            if(mask[i][j]>0) then
                if(base[i][j]>=0) then
                    if(base[i][j]>0) then 
                        gpu:pushfg(0x0000FF)
                        gpu:pushbg(0xFFFFFF)
                        gpu:set(i+1,j+1,tostring(base[i][j]))
                        gpu:popbg()
                        gpu:popfg()
                    end
                else
                    gpu:pushfg(0xFF0000)
                    gpu:set(i+1,j+1,"X")
                    gpu:popfg()
                end
            elseif(mask[i][j]<0) then
                gpu:pushfg(0xFFFF00)
                gpu:set(i+1,j+1,"?")
                gpu:popfg()
            else
                gpu:pushbg(0xFFFFFF)
                gpu:set(i+1,j+1," ")
                gpu:popbg()
            end
        end
        
        gpu:set(i+1,base.col+2,"|")
    end

    for i=1,base.col+2,1 do
        gpu:set(base.line+2,i,"-")
    end
end

local function SetStatus(mp,str)
    gpu:set(mp.line+3,1,">>" .. str .. "<<")
end

-- Game 
local function main()
    -- printMap(generateMap(10,10,5),generateBlankMask(10,10,true))
    local maxline=10
    local maxcol=10
    local maxmine=5
    if(argc==3) then
        maxline=tonumber(args[1])
        maxcol=tonumber(args[2])
        maxmine=tonumber(args[3])
    end

    local mp=generateMap(maxline,maxcol,maxmine)
    local mask=generateBlankMask(maxline,maxcol,0)
    local marked=0
    local marked_right=0

    printMap(mp,mask)

    while true do
        SetStatus(mp,"Marked " .. marked .. "/" .. maxmine)

        local e=WaitMultipleEvent("touch","interrupted")
        if(e.event=="interrupted") then 
            SetStatus(mp,"Game stopped. Click to exit.")
            return         
        end

        local line=e.y-1
        local col=e.x-1

        if(not (line<1 or col<1 or line>mp.line or col>mp.col) ) then
            if(e.button==0) then
                if(mp[line][col]<0) then
                    -- Game over
                    mask=generateBlankMask(mp.line,mp.col,1)

                    printMap(mp,mask)
                    SetStatus(mp,"Game Over! Click to exit.")
                    return 
                elseif(mask[line][col]==0) then
                    if(mp[line][col]>0) then 
                        mask[line][col]=1
                    else 
                        -- If click on 0, then try to unlock other blocks with 0 (BFS)
                        local bus=Queue.new()
                        local x={}
                        x.line=line
                        x.col=col
                        bus:push(x)

                        local cnt=1
                        while(not bus:empty()) do
                            SetStatus(mp,"Counting " .. cnt)
                            --os.sleep(0)

                            local x=bus:pop()
                            cnt=cnt+1

                            if(x.line>1 and 
                               mp[x.line-1][x.col]==0 and mask[x.line-1][x.col]==0) then
                                local t={}
                                t.line=x.line-1
                                t.col=x.col
                                mask[x.line-1][x.col]=1
                                bus:push(t)
                            end

                            if(x.line<mp.line and 
                               mp[x.line+1][x.col]==0 and mask[x.line+1][x.col]==0) then
                                local t={}
                                t.line=x.line+1
                                t.col=x.col
                                mask[x.line+1][x.col]=1
                                bus:push(t)
                            end

                            if(x.col>1 and 
                               mp[x.line][x.col-1]==0 and mask[x.line][x.col-1]==0) then
                                local t={}
                                t.line=x.line
                                t.col=x.col-1
                                mask[x.line][x.col-1]=1
                                bus:push(t)
                            end

                            if(x.col<mp.col and 
                               mp[x.line][x.col+1]==0 and mask[x.line][x.col+1]==0) then
                                local t={}
                                t.line=x.line
                                t.col=x.col+1
                                mask[x.line][x.col+1]=1
                                bus:push(t)
                            end
                        end
                    end
                    
                    printMap(mp,mask)
                end
            else
                if(mask[line][col]==0) then
                    mask[line][col]=-1
                    marked=marked+1
                    if(mp[line][col]<0) then
                        marked_right=marked_right+1
                    end
                elseif(mask[line][col]==-1) then
                    mask[line][col]=0
                    marked=marked-1
                    if(mp[line][col]<0) then
                        marked_right=marked_right-1
                    end
                end

                printMap(mp,mask)

                if(marked_right==maxmine and marked==maxmine) then
                    SetStatus(mp,"Game Finish. Thank you for playing. Click to exit.")
                    return
                end
            end
        end
    end
end


print("Mine Sweeper")
print("Author: Github/Kiritow")
main()

WaitEvent("touch")
gpu:clear()
