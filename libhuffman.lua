-- huffman_lib
-- Created by Kiritow
-- This library is designed for compressing code. The input should not contain any \t or \n.
-- Huffman deflate
local function hdef(data)
    local ctb={}
    for i=1,data:len() do
        local c=data:sub(i,i)
        if(not ctb[c]) then
            ctb[c]=1
        else
            ctb[c]=ctb[c]+1
        end
    end

    local pool={}
    for k,v in pairs(ctb) do
        table.insert(pool,{k,v})
    end
    ctb=nil

    local poolsz=#pool
    repeat
        table.sort(pool,function(a,b) return a[2]>b[2] end)
        local t={nil,pool[poolsz-1][2]+pool[poolsz][2],L=pool[poolsz-1],R=pool[poolsz]}
        table.remove(pool)
        table.remove(pool)
        table.insert(pool,t)
        poolsz=poolsz-1
    until poolsz<2

    local sdic={}
    local dic={}
    local function _encode_tree(node,prefix)
        if(node[1]) then
            table.insert(sdic,node[1])
            table.insert(sdic,"\n\n")
            dic[node[1]]=prefix
        else
            table.insert(sdic,'\t')
            if(node.L) then
                _encode_tree(node.L,prefix .. "0")
            else
                table.insert(sdic,'\n')
            end

            if(node.R) then
                _encode_tree(node.R,prefix .. "1")
            else
                table.insert(sdic,'\n')
            end
        end
    end
    _encode_tree(pool[1],"")

    local result=''
    local tmp=''
    local function _encode()
        local x=0
        for j=1,8 do
            x=x<<1
            if(tmp:sub(j,j)=="1") then
                x=x | 1
            end
        end
        result=result .. string.pack(">B",x)
    end
    
    for i=1,data:len() do
        tmp=tmp .. dic[data:sub(i,i)]
        while(tmp:len()>=8) do
            _encode()
            tmp=tmp:sub(9)
        end
    end

    if(tmp:len()>0) then
        _encode()
    end

    print("Dic Length: ",string.len(table.concat(sdic,"")))
    print("Padding Length: ",8-tmp:len())

    return table.concat(sdic, "") .. string.pack(">B",8-tmp:len()) .. result
end

local function hinf(data)
    local function _read_tree(i,node)
        if(data:sub(i,i)~='\t') then
            node[1]=data:sub(i,i)
        end

        i=i+1

        if(data:sub(i,i)~='\n') then
            node.L={}
            i=_read_tree(i,node.L)
        else
            i=i+1
        end

        if(data:sub(i,i)~='\n') then
            node.R={}
            i=_read_tree(i,node.R)
        else
            i=i+1
        end

        return i
    end
    local root={}
    local data_pos=_read_tree(1,root)
    
    local dic={}
    local function _make_dic(node,prefix)
        if(node[1]) then
            dic[node[1]]=prefix
        else
            if(node.L) then
                _make_dic(node.L,prefix .. "0")
            end

            if(node.R) then
                _make_dic(node.R,prefix .. "1")
            end
        end
    end
    _make_dic(root,"")

    print("Data Length: ",data_pos)
    local padding=string.unpack(">B",data:sub(data_pos,data_pos))
    print("Padding Length: ",padding)

    local dtmp=''
    local function decomp(beginat,endat)
        for i=beginat,endat do
            local x=string.unpack(">B",data:sub(i,i))
            local tmp=''
            for i=1,8 do
                if(x&1==1) then tmp='1' .. tmp
                else tmp='0' .. tmp
                end
                x=x>>1
            end
            dtmp=dtmp .. tmp
        end
    end
    
    if(padding==0) then
        decomp(data_pos+1,data:len())
    else
        decomp(data_pos+1,data:len()-1)
        local x=string.unpack(">B",data:sub(-1))
        x=x>>padding
        local tmp=''
        for i=1,8-padding do
            if(x&1==1) then tmp='1' .. tmp
            else tmp='0' .. tmp
            end
            x=x>>1
        end
        dtmp=dtmp .. tmp
    end

    local result=''
    local tmp=''
    for i=1,dtmp:len() do
        tmp=tmp .. dtmp:sub(i,i)
        for k,v in pairs(dic) do
            if(v==tmp) then
                result=result .. k
                tmp=''
                break
            end
        end
    end

    return result
end

return {
    hinf=hinf,
    hdef=hdef
}