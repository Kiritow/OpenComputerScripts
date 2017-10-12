--[[ 
    Local netcard wrapper
        This require should return a table like:
        {
            broadcast=function(port,...):bool
            send=function(uuid,port,...):bool
            open=function(port):bool
            isOpen=function(port):bool
            close=function(port):bool
        }
--]]
local netcard=require("localNetcard")

-- Check Netcard
if(netcard.broadcast==nil or 
    netcard.send==nil or 
    netcard.open==nil or 
    netcard.isOpen==nil or 
    netcard.close==nil) then
    print("Error: netcard invalid.")
end

local sker= -- Socket Kernel Table
    {
        fdset= -- Store information of sockets
        {
            --[[
            status : string ="Ready" "Connected" "Closed"
            remote_hwport : int
            remote_cookie : string
            --]]
        }
    }

local arpker={} -- ARP Kernel Table


function _findFirstAvaliableSocket()
    local i=0 
    while ( sker.fdset[i] ~= nil ) do i=i+1 end
    return i
end

function _doCreateSocket(sfd)
    if(sker.fdset[sfd]~=nil) then return false,"sfd invalid"
    else
        sker.fdset[sfd]=
            {
                status="Ready"
            }
        return true,"Success"
    end
end

function _getSocketStatus(sfd)
    if(sker.fdset[sfd]==nil) then return nil
    else
        return sker.fdset[sfd].status
    end
end

function _setSocketStatus(sfd,status,...)
    if(sker.fdset[sfd]==nil) then return false
    else
        sker.fdset[sfd].status=status
        if(status=="Connected") then
            sker.fdset[sfd].remote_hwport=arg[1]
        end
        return true
    end
end

function _isPortValid(port)
    return port>0 and port<65536
end

function _doConnect(sfd,remote_uuid,port) -- Connect to a remote device via uuid and port
    -- Send SYN package (1,1,1)
    local syn=string.pack("iii",1,1,1)
    if(not netcard.send(remote_uuid,port,syn)) then 
        return -1,"Network error"
    end
    -- Wait 1.5 seconds for SYN+ACK (1,1,3)
    local e,remote_hwport=event.pull(1.5,"net_synack")
    if(e==nil) then 
        return -2,"Connection timed out"
    end
    --- Send ACK package (1,1,2)
    local ack=string.pack("iii",1,1,2)
    if(not netcard.send(remote_uuid,port,ack)) then 
        return -1,"Network error"
    end

    -- Connection established
    return 0,"Success",remote_hwport
end

function _isInArpCache(tag) -- Check ARP Check Table with tag for uuid
    if(arpker[tag]~=nil) then
        return true,arpker[tag].uuid
    else
        return false
    end
end

function _generateARPQuest(tag) -- Generate a ARP quest
    local s=string.pack("iiii",1,0,1,string.length(tag))
    s=s..tag
    return s
end

function _doArpBroadcastQuery(tag) -- Broadcast ARP quest to hardware port 9 (arp)
    if(netcard.broadcast(9,tag)) then return true,"Success"
    else return false,"Netcard error"
end

function socket() -- Allocate a new socket
    local idx=_findFirstAvaliableSocket()
    local ret,emsg=_doCreateSocket(idx)
    if(not ret) then
        return -1,emsg
    else
        return ret,emsg
    end
end

function connect(sfd,remote_tag,port) -- Connect to a remote device
    if(_getSocketStatus(sfd)~="Ready") then
        return -1,"Socket not ready"
    elseif(not _isPortValid(port)) then
        return -2,"Port Invalid"
    else
        -- Try to resolve remote_tag to remote_uuid
        local remote_uuid=do_arp_query(remote_tag)
        if(remote_uuid == nil) then
            return -3,"Tag can not be resolved into uuid"
        else
            local eret,emsg,remote_hwport=_doConnect(sfd,remote_uuid,port)
            if(eret==0) then
                _setSocketStatus(sfd,"Connected",remote_hwport)
                return 0,"Success"
            else
                return eret,emsg
            end
        end
    end
end

function bind(sfd,port) -- Bind socket at specific port

end

function listen(sfd,sz) -- Set size of queue for waiting connections

end

function accept(sfd) -- Accept Connection

end

function send(sfd,...) -- Standard Network I/O

end

function recv(sfd) -- Standard Network I/O

end

function shutdown(sfd) -- Close Socket

end

function close(sfd) -- Close Socket

end

function do_dhcp_client() -- Connect to DHCP Server and try to get a tag.

end

function do_arp_broadcast() -- ARP: Broadcast tag and uuid information of this device

end

function arp_listener() -- ARP: Listen to arp broadcast and record informations. Notice that this listener also replies to specific arp-request

end

function do_arp_query(tag) -- ARP: Query uuid with tag, might send arp-request
    local ret,uuid=_isInArpCache(tag)
    if(ret) then return uuid
    else
        local quest=_generateARPQuest(tag)
        for i=1,3,1 do
            if(_doArpBroadcastQuery(quest)) then
                local e,etag,euuid=event.pull(0.5,"net_newarp")
                if(e~=nil) then return euuid end
            end
        end
        return nil -- Failed to query arp in 3 tries.
    end
end

function run_arp() -- Start ARP Services in background

end

function run_dhcp_client() -- Start DHCP Client in background

end

function run_tcp() -- Start TCP Services in background

end