local function shrink(source)
    local len=string.len(source)
    local qouted=nil
    local last_space=false
    local output=''
    for i=1,len do
        local this=string.sub(source,i,i)
        if(not qouted) then
            if(this=='"' or this=="'") then 
                qouted=this
                last_space=false
                output=output .. this
            elseif(this==' ' or this=='\n' or this=='\r') then
                if(not last_space) then 
                    last_space=true
                    output=output .. ' '
                end
            else
                last_space=false
                output=output .. this
            end
        else
            if(this==qouted) then 
                qouted=nil
                last_space=false
                output=output .. this
            else
                output=output .. this
            end
        end
    end
    return output
end

