-- Global: https://pastebin.com/fiCuN16y

local computer=require('computer')
print("Grab Pastebin Installer v1.1")
print("Thank you for installing Grab - The official OpenComputerScripts Installer.")
local before=computer.uptime()
os.execute("wget https://raw.githubusercontent.com/Kiritow/OpenComputerScripts/master/grab.lua -f")
print("Almost done, just a few steps...")
os.execute("grab update")
print(string.format("[Done] Grab installed in %.2fs.",computer.uptime()-before))
