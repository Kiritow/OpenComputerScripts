-- Mine Sweeper Game
-- Author: Github/Kiritow

require("kgui")
require("libevent")
local component=require("component")

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
                    gpu:set(i+1,j+1,tostring(base[i][j]))
                else
                    gpu:pushfg(0xFF0000)
                    gpu:set(i+1,j+1,"X")
                    gpu:popfg()
                end
            elseif(mask[i][j]<0) then
                gpu:pushfg(0xFFFF00)
                gpu:set(i+1,j+1,"?")
                gpu:popfg()
            end
        end
        
        gpu:set(i+1,base.col+2,"|")
    end

    for i=1,base.col+2,1 do
        gpu:set(base.line+2,i,"-")
    end
end

-- Game 
local function main()
    -- printMap(generateMap(10,10,5),generateBlankMask(10,10,true))
    local mp=generateMap(10,10,5)
    local mask=generateBlankMask(10,10,0)

    printMap(mp,mask)

    while true do
        local e=WaitMultipleEvent("touch","interrupted")
        if(e.event=="interrupted") then break end

        local line=e.y-1
        local col=e.x-1

        if(not (line<1 or col<1 or line>mp.line or col>mp.col) ) then
            if(e.button==0) then
                if(mp[line][col]<0) then
                    mask=generateBlankMask(mp.line,mp.col,1)

                    printMap(mp,mask)
                    os.sleep(5)
                    return 
                elseif(mask[line][col]==0) then
                    mask[line][col]=1
                    printMap(mp,mask)
                end
            else
                if(mask[line][col]==0) then
                    mask[line][col]=-1
                elseif(mask[line][col]==-1) then
                    mask[line][col]=0
                end

                printMap(mp,mask)
            end
        end
    end
end


print("Mine Sweeper")
print("Author: Github/Kiritow")
main()