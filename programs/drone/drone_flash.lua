-- Drone Flash
-- Created by Kiritow
local component=require('component')
local shrink=require('shrink')
require('libevent')
print("Please insert new eeprom. (Or press Ctrl+C if the eeprom is already inserted.)")
while true do
    local e=WaitMultipleEvent("interrupted","component_added")
    if(e.event=="interrupted" or (e.event=="component_added" and e.componentType=="eeprom")) then 
        break
    end
end
if(not component.eeprom) then
    print("No eeprom detected. Exited.")
    return
end
print("EEPROM detected: " .. component.eeprom.address)
print("[Working] Reading drone bios from disk...")
local f=io.open("drone_bios.lua","r")
if(not f) then 
    print("[Error] Unable to open drone_bios.lua.")
    return 
end
local data=f:read("a")
f:close()
local szBefore=string.len(data)
print("Original data size: " .. szBefore)
print("[Working] Syntax checking...")
local xt={}
local fn,err=load(data,"DroneBIOS","t",xt)
if(not fn) then
    print("Found syntax error: " .. err)
    return
end
print("[Working] Getting DroneBIOS version...")
pcall(fn)
local drone_bios_version=xt['drone_version']
if(not drone_bios_version) then 
    print("[Error] Unable to get version tag.")
    return
end
print("Version tag: " .. drone_bios_version)
print("[Working] Shrinking...")
data=shrink(data)
local szAfter=string.len(data)
print("Shrank data size: " .. szAfter)
if(component.eeprom.getSize()<szAfter) then
    print("[Error] Not enough space in eeprom. Need " .. szAfter-component.eeprom.getSize() .. " more bytes.")
    return
end
print("[Working] Writing to eeprom...")
component.eeprom.set(data)
print("[Working] Setting eeprom label...")
component.eeprom.setLabel(drone_bios_version)
print("[Done] Remember to insert the original eeprom!")