-- Teleport Calculator

local function getEUStr(eu)
    if(eu<1000) then
        return string.format("%d EU",eu)
    elseif(eu<1000000) then
        return string.format("%.2fK EU",eu/1000)
    else
        return string.format("%.2fM EU",eu/1000000)
    end
end

local function teleport_calc(dis,item) 
    if(item==nil) then item=40 end
    local ret=(1000+100*item)*math.pow(dis+10,0.7)
    print("Teleport Steve with " .. item .. " items to " .. dis .. "m away needs " .. getEUStr(ret))
    return ret
end

return teleport_calc