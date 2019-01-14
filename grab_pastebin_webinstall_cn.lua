-- China: https://pastebin.com/JXxKZxwh

local computer=require('computer')
print("Grab Pastebin Installer v1.1 [China Mirror]")
print("Thank you for installing Grab - The official OpenComputerScripts Installer.")
local before=computer.uptime()
os.execute("wget http://kiritow.com:3000/Kiritow/OpenComputerScripts/raw/master/grab.lua -f")
print("Almost done, just a few steps...")
os.execute("grab update --cn")
print(string.format("[Done] Grab installed in %.2fs.",computer.uptime()-before))
