function socket() -- Allocate a new socket

end

function connect(sfd,remote_tag,port) -- Connect to a remote device

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

function do_arp_query() -- ARP: Query uuid with tag, will send arp-request

end

function run_arp() -- Start ARP Services in background

end

function run_dhcp_client() -- Start DHCP Client in background

end