local function grab_installer(info)
    print("Thank you for installing Grab - The official OpenComputerScripts Installer.")
    print("Installer Loaded by: " .. info.version)
    if(info.grab_options and info.grab_options["cn"]) then
        print("China mirror detected.")
        os.execute("grab update --cn")
    else
        os.execute("grab update")
    end
    print("Programs info has been updated.")
end

return grab_installer