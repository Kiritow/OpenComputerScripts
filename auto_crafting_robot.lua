-- Auto Crafting Robot Client
-- Requires:
--      Craft upgrade and inventory upgrade
--      Wireless network card

require("libevent")
local component=require("component")
local modem=component.list("modem")
if(modem==nil) then
    error("Modem is required")
else
    modem=component.proxy("modem")
end

