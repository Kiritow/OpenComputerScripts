-- Teleport Calculator
function teleport_calc(dis,item) 
    if(item==nil) then item=40 end
    local ret=(1000+100*item)*math.pow(dis+10,0.7)
    print("Teleport Steve with " .. item .. " items to " .. dis .. " m away needs " .. getEUStr(ret))
    return ret
end
