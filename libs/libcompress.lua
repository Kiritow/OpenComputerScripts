-- LibCompress
-- Another version of libhuffman for general purpose
-- Created by Kiritow
-- Use Lua 5.3 feature

-- checkType(name,1,"string")
local function checkType(arg,id,which)
    return assert(type(arg)==which,string.format("bad argument #%d. %s expected, got %s",id,which,type(arg)))
end

local BitWriter
BitWriter={
    _newobj_mt={
        ["__index"]=function(tb,key)
            if(type(key)=="string" and key~="new" and key:sub(1,1)~="_") then
                return BitWriter[key]
            end
            return nil
        end
    },

    new=function()
        local this={}
        this.buffer=''
        this.working=0
        this.cached=0

        setmetatable(this,BitWriter._newobj_mt)

        return this
    end,

    _pushbit=function(this,b)
        this.working= ( this.working << 1 ) | b
        this.cached=this.cached+1

        if(this.cached==8) then
            this.buffer=this.buffer .. string.pack(">B",this.working)
            this.working=0
            this.cached=0
        end
    end,

    pushbit=function(this,b)
        if( ( type(b)=="number" and b==0) or ( type(b)=="string" and b=="0") ) then
            BitWriter._pushbit(this,0)
        elseif( (type(b)=="number" and b==1) or (type(b)=="string" and b=="1") ) then
            BitWriter._pushbit(this,1)
        else
            error("pushed bit should be 0 or 1")
        end
    end,

    pushbits=function(this,bstr)
        if(type(bstr)=="string") then
            for i=1,bstr:len() do
                BitWriter.pushbit(this,bstr:sub(i,i))
            end
        else
            error("pushed bitstr must be 'string'")
        end
    end,

    -- Don't use this object after calling get().
    get=function(this)
        if(this.cached~=0) then
            print(string.format("Current bit: %d, not aligned to 8. Padding...",this.cached))
            local padlen=0
            while(this.cached~=0) do -- Pad '1' at the end.
                BitWriter._pushbit(this,1)
                padlen=padlen+1
            end

            return this.buffer,padlen
        else
            return this.buffer,0
        end
    end,
}

local BitReader
BitReader={
    _newobj_mt={
        ["__index"]=function(tb,key)
            if(type(key)=="string") then
                if(key~="new" and key:sub(1,1)~="_") then
                    return BitReader[key]
                else
                    error("Cannot call new(...) or private methods from object.")
                end
            end
            return nil
        end
    },

    new=function(in_buffer,in_padlen)
        local this={}
        this.buffer=in_buffer
        this.padlen=in_padlen
        this.working=0
        this.cached=0

        setmetatable(this,BitReader._newobj_mt)
        return this
    end,

    nextbit=function(this)
        if(this.cached==0) then
            if(this.buffer:len()>1) then
                this.working=string.unpack(">B",this.buffer:sub(1,1))
                this.cached=8
                this.buffer=this.buffer:sub(2)
            elseif(this.buffer:len()==1) then
                this.working=string.unpack(">B",this.buffer:sub(1,1))
                this.buffer=''
                if(this.padlen>0) then
                    this.working=this.working >> this.padlen
                end
                this.cached=8-this.padlen
            else
                return nil -- no bit left.
            end
        end

        this.cached=this.cached-1
        return (this.working & ( 1 << (this.cached) )) > 0 and 1 or 0
    end,

    nextbits=function(this,len)
        local ret=""
        for i=1,len do
            ret=ret .. BitReader.nextbit(this)
        end
        return ret
    end,

    nextchar=function(this)
        local result=0
        for i=1,8 do
            result= (result << 1) | BitReader.nextbit(this)
        end
        return string.char(result)
    end,
}

-- "A" --> 65 --> 0x41 --> "01000001"
local function charToBitStr(c)
    local n=c:byte(1)
    local vtb={
        "0001","0010","0011","0100",
        "0101","0110","0111","1000",
        "1001","1010","1011","1100",
        "1101","1110","1111"
    }
    vtb[0]="0000"
    return vtb[n//16] .. vtb[n%16]
end

-- Huffman Deflate
local function hdef(data)
    checkType(data,1,"string")

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

    local poolsz=#pool
    repeat
        table.sort(pool,function(a,b) return a[2]>b[2] end)
        local t={nil,pool[poolsz-1][2]+pool[poolsz][2],L=pool[poolsz-1],R=pool[poolsz]}
        table.remove(pool)
        table.remove(pool)
        table.insert(pool,t)
        poolsz=poolsz-1
    until poolsz<2

    local dic={}
    local writer=BitWriter.new()
    local function _encode_tree(node,prefix)
        if(node[1]) then
            writer:pushbit(1)
            writer:pushbits(charToBitStr(node[1]))
            dic[node[1]]=prefix
        else
            writer:pushbit(0)
            if(node.L) then
                _encode_tree(node.L,prefix .. "0")
            end

            if(node.R) then
                _encode_tree(node.R,prefix .. "1")
            end
        end
    end
    _encode_tree(pool[1],"")

    for i=1,data:len() do
        writer:pushbits(dic[data:sub(i,i)])
    end

    local defdata,defpad=writer:get()
    return string.pack(">B",defpad) .. defdata
end

-- Huffman Inflate
local function hinf(data)
    checkType(data,1,"string")

    local padlen=string.unpack(">B",data:sub(1,1))
    local reader=BitReader.new(data:sub(2),padlen)

    xdic={}
    local function _decode_tree(prefix)
        local flag=reader:nextbit()
        if(flag==1) then
            xdic[prefix]=reader:nextchar()
        else
            _decode_tree(prefix .. "0")
            _decode_tree(prefix .. "1")
        end
    end

    _decode_tree('')

    local output=''
    local working=''
    while true do
        local b=reader:nextbit()
        if(not b) then break end
        working=working .. b
        if(xdic[working]) then
            output=output .. xdic[working]
            working=''
        end
    end

    if(working:len()>0) then
        if(xdic[working]) then
            output=output .. xdic[working]
        else
            print("WARNING: invalid sequence left as " .. working)
        end
    end

    return output
end

return {
    ["deflate"]=hdef,
    ["inflate"]=hinf
}