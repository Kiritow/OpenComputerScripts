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
local netcard = require("localNetcard")
local event = require("event")
local uuid = require("uuid")
require("vector")

-- Check Netcard
if
    (netcard.broadcast == nil or netcard.send == nil or netcard.open == nil or netcard.isOpen == nil or
        netcard.close == nil)
 then
    print("Error: netcard invalid.")
end

local sker = {
    -- Socket Kernel Table
    fdset = {} -- Store information of sockets
}

local arpker = {} -- ARP Kernel Table

local tcp_syn = string.pack("iii", 1, 1, 1)
local tcp_synack = string.pack("iii", 1, 1, 3)
local tcp_ack = string.pack("iii", 1, 1, 2)
local arp_broadcast = string.pack("iii", 1, 0, 0)
local arp_quest = string.pack("iii", 1, 0, 1)
local dhcp_quest = string.pack("iii", 0, 0, 1)
local dhcp_ack = string.pack("iii", 0, 0, 2)
local trans_data = string.pack("iii", 1, 2, 1)
local trans_ack = string.pack("iii", 1, 2, 2)

function _findFirstAvaliableSocket()
    local i = 0
    while (sker.fdset[i] ~= nil) do
        i = i + 1
    end
    return i
end

function _doCreateSocket(sfd)
    if (sker.fdset[sfd] ~= nil) then
        return false, "sfd invalid"
    else
        sker.fdset[sfd] = {
            status = "Ready",
            -- remote_cookie
            -- local_cookie
            sendBus = Vector.new(),
            recvBus = Vector.new()
        }
        return true, "Success"
    end
end

function _getSocketStatus(sfd)
    if (sker.fdset[sfd] == nil) then
        return nil
    else
        return sker.fdset[sfd].status
    end
end

function _setSocketStatus(sfd, status, ...)
    if (sker.fdset[sfd] == nil) then
        return false
    else
        sker.fdset[sfd].status = status
        if (status == "Connected") then
            sker.fdset[sfd].remote_cookie = arg[1]
        end
        return true
    end
end

function _isPortValid(port)
    return port > 0 and port < 65536
end

function _generateNewCookie() -- Generate a new cookie
    return uuid.next()
end

function _doConnect(sfd, remote_uuid, port) -- Connect to port 10 of a remote device with virtual port
    -- Send SYN package (1,1,1)
    local syn = tcp_syn
    if (not netcard.send(remote_uuid, 10, syn, port)) then
        return -1, "Network error"
    end
    -- Wait 1.5 seconds for SYN+ACK (1,1,3)
    local e, remote_cookie = event.pull(1.5, "net_synack")
    if (e == nil) then
        return -2, "Connection timed out"
    end
    --- Send ACK package (1,1,2)
    local ack = tcp_ack
    local newcookie = _generateNewCookie()
    -- Update FDSet Cookie
    sker.fdset[sfd].remote_cookie = remote_cookie
    sker.fdset[sfd].local_cookie = newcookie
    if (not netcard.send(remote_uuid, 10, ack, remote_cookie, newcookie)) then
        return -1, "Network error"
    end

    -- Connection established
    return 0, "Success", remote_cookie
end

function _isInArpCache(tag) -- Check ARP Check Table with tag for uuid
    if (arpker[tag] ~= nil) then
        return true, arpker[tag].uuid
    else
        return false
    end
end

function _doArpBroadcastQuery(header, tag) -- Broadcast ARP quest to hardware port 9 (arp)
    if (netcard.broadcast(9, header, tag)) then
        return true, "Success"
    else
        return false, "Netcard error"
    end
end

function socket() -- Allocate a new socket
    local idx = _findFirstAvaliableSocket()
    local ret, emsg = _doCreateSocket(idx)
    if (not ret) then
        return -1, emsg
    else
        return ret, emsg
    end
end

function connect(sfd, remote_tag, port) -- Connect to a remote device
    if (_getSocketStatus(sfd) ~= "Ready") then
        return -1, "Socket not ready"
    elseif (not _isPortValid(port)) then
        return -2, "Port Invalid"
    else
        -- Try to resolve remote_tag to remote_uuid
        local remote_uuid = do_arp_query(remote_tag)
        if (remote_uuid == nil) then
            return -3, "Tag can not be resolved into uuid"
        else
            local eret, emsg, remote_cookie = _doConnect(sfd, remote_uuid, port)
            if (eret == 0) then
                _setSocketStatus(sfd, "Connected", remote_cookie)
                return 0, "Success"
            else
                return eret, emsg
            end
        end
    end
end

function bind(sfd, port) -- Bind socket at specific port
end

function listen(sfd, sz) -- Set size of queue for waiting connections
end

function accept(sfd) -- Accept Connection
end

function send(sfd, ...) -- Standard Network I/O
end

function recv(sfd) -- Standard Network I/O
end

function shutdown(sfd) -- Close Socket
end

function close(sfd) -- Close Socket
end

function do_arp_query(tag) -- ARP: Query uuid with tag, might send arp-request
    local ret, uuid = _isInArpCache(tag)
    if (ret) then
        return uuid
    else
        local questHeader = _generateARPQuestHeader()
        for i = 1, 3, 1 do
            if (_doArpBroadcastQuery(questHeader, tag)) then
                local e, etag, euuid = event.pull(0.5, "net_newarp")
                if (e ~= nil and etag == tag) then
                    return euuid
                end
            end
        end
        return nil -- Failed to query arp in 3 tries.
    end
end

function run_arp() -- Start ARP Services in background
    event.listen(
        "modem_message",
        function(_event, _receiver, sender, _port, _distance, ...)
            if (_port == 9) then
                if (arg[1] == arp_broadcast and arg[2] ~= nil) then
                    -- Received an ARP Broadcast
                    if (arpker[arg[2]] == nil) then
                        arpker[arg[2]] = sender
                        event.push("net_newarp", arg[2], sender)
                    elseif (arpker[arg[2]] ~= sender) then
                        arpker[arg[2]] = sender
                        event.push("net_arpchanged", arg[2], sender)
                    end -- arpker check
                elseif (arg[1] == arp_quest and arg[2] ~= nil and arg[2] == arpker.thisDevice) then
                    -- Received an ARP Quest Broadcast and it points this device
                    netcard.send(sender, 9, arp_broadcast, arg[2])
                end -- arg1 and arg2 check
            end -- port check
        end
    ) -- callback
    netcard.open(9)
end

function run_dhcp_client() -- Start DHCP Client in background
    local finished = false
    event.listen(
        "modem_message",
        function(_event, _receiver, sender, port, _distance, ...)
            if (port == 8 and arg[1] == dhcp_ack) then
                -- Receive DHCP Answer
                arpker.thisDevice = arg[2]
                -- Close Local Port
                network.close(7)
                -- Change flag to stop running
                finished = true
                -- Unregister this callback
                return false
            end
        end
    )
    network.open(7)
    while not finished do
        network.broadcast(8, dhcp_quest)
        os.sleep(1)
    end
end

function run_tcp() -- Start TCP Services in background
    event.listen(
        "modem_message",
        function(_event, _receiver, sender, port, _distance, ...)
            if (port == 10) then
                if (arg[1] == tcp_syn) then --SYN
                    event.push("net_newsyn", sender, arg[2])
                end
            elseif (port == 11) then
                if (arg[1] == tcp_synack) then --SYN/ACK
                    event.push("net_newsynack", sender)
                end
            end
        end
    )
    event.listen(
        "modem_message",
        function(_event, _receiver, sender, port, _distance, ...)
            if (port == 12) then
                if (arg[1] == trans_data and arg[2] ~= nil) then
                    -- Find cookie and push data
                    for k, t in pairs(sker.fdset) do
                        if (t.local_cookie == arg[2]) then
                            t.recvBus.push_back(arg[3])
                            break
                        end
                    end
                end
            end
        end
    )
    netcard.open(10)
    netcard.open(11)
end
