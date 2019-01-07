-- LibKeepUp
-- Avoid 'too long without yielding'

-- Experimental.
local generator
if(os.sleep) then -- Oh! We are in OpenComputers
    local computer=require('computer')
    local __last_uptime=computer.uptime()
    generator=function(sec)
        return function()
            local now=computer.uptime()
            if(now-__last_uptime>=sec) then
                os.sleep(0)
                __last_uptime=now
            end
        end
    end
else -- In Standard Lua
    generator=function()
        return function() end
    end
end

return generator