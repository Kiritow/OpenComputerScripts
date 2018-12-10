-- LibFTP::STD
-- Created by Kiritow
-- This library does not handle network stuff. So it needs socket adapter to function normally.

local function readline(socket,fd,sep)
    sep=sep or "\r\n"
    local tmp=''
    while true do
        tmp = tmp .. socket.read(fd,1)
        if(tmp:sub(-2)==sep) then return tmp end
    end
end

local function get_response(socket,fd)
    while true do
        local line=readline(socket,fd):sub(1,-3)
        local code,text=string.match(line,"(%d%d%d) (.*)")
        if(code) then return math.tointeger(code),text end
    end
end

local function ftp_connect(t,site,port,user,pass)
    assert(type(site)=="string","site should be string")
    port=port or 21
    user=user or "anonymous"
    pass=pass or "anonymous"
    t.handle=t.socket.create()
    t.socket.connect(t.handle,site,port)
    get_response(t.socket,t.handle)
    t.socket.send(t.handle,"USER " .. user .. "\r\n")
    if(get_response(t.socket,t.handle)~=331) then
        error("Failed to login. Username invalid.")
    end
    t.socket.send(t.handle,"PASS " .. pass .. "\r\n")
    if(get_response(t.socket,t.handle)~=230) then
        error("Failed to login. Password invalid.")
    end
end

local function ftp_pasv(t)
    t.socket.send(t.handle,"PASV\r\n")
    local code,res=get_response(t.socket,t.handle)
    if(code~=227) then
        error("PASV with wrong response")
    end
    local a,b,c,d,e,f=string.match(res,"%((%d+),(%d+),(%d+),(%d+),(%d+),(%d+)%)")
    local ip=a .. '.' .. b .. '.' .. c .. '.' .. d
    local port=math.tointeger(tonumber(e)*256+tonumber(f))
    return ip,port
end

local function ftp_list(t)
    local ip,port=ftp_pasv(t)

    t.socket.send(t.handle,"LIST\r\n")

    -- Connect with tunnel here.
    local tunnel=t.socket.create()
    t.socket.connect(tunnel,ip,port)

    local code,res=get_response(t.socket,t.handle)
    if(code~=150 and code~=125) then
        error("LIST data connection not opened: " .. code)
    end

    local data=''
    pcall(function()
        while true do data=data .. t.socket.read(tunnel,1024) end
    end)

    code,res=get_response(t.socket,t.handle)
    if(code~=226 and code~=250) then
        error("LIST data connection not finished." .. code)
    end
    return data
end

local function ftp_upload(t,local_filename,remote_filename)
    assert(type(local_filename)=="string","Local filename should be string.")
    remote_filename=remote_filename or local_filename
    
    local f=io.open(local_filename,"rb")
    local data=f:read("a")
    f:close()

    t.socket.send(t.handle,"TYPE I\r\n")
    local code,res=get_response(t.socket,t.handle)
    if(code~=200) then
        error("Unable to switch TYPE.")
    end

    local ip,port=ftp_pasv(t)

    t.socket.send(t.handle,"STOR " .. remote_filename .. "\r\n")
    
    local tunnel=t.socket.create()
    t.socket.connect(tunnel,ip,port)

    local code,res=get_response(t.socket,t.handle)
    if(code~=150 and code~=125) then
        error("STOR data connection not opened: " .. code)
    end

    t.socket.send(tunnel,data)
    t.socket.close(tunnel)

    code,res=get_response(t.socket,t.handle)
    if(code~=226 and code~=250) then
        error("STOR data connection not finished." .. code)
    end
end

local function ftp_close(t)
    t.socket.close(t.handle)
end

local function FTP(socket_adapter)
    local t={}
    t.closed=false
    t.socket=socket_adapter
    t.connect=ftp_connect
    t.list=ftp_list
    t.upload=ftp_upload
    t.close=ftp_close
    return t
end

return FTP