-- Teleport Calculator
local function getEUStr(eu)
    if(eu<1000) then
        return '' .. math.ceil(eu)
    elseif(eu<1000*1000) then
        return '' .. math.ceil(eu/1000) .. 'K,' .. getEUStr(eu%1000)
    else
        return '' .. math.ceil(eu/1000000) .. 'M,' .. getEUStr(eu%1000000)
    end
end

function teleport_calc(dis,item) 
    if(item==nil) then item=40 end
    local ret=(1000+100*item)*math.pow(dis+10,0.7)
    print("Teleport Steve with " .. item .. " items to " .. dis .. "m away needs " .. getEUStr(ret) .. " EU")
    return ret
end
