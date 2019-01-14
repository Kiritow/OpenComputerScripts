-- Shrink FSM
-- Created by Kiritow

local function isSpace(c)
    return (c==" " or c=="\n" or c=="\r" or c=="\t")
end

local function GetTrans()
    -- state_trans(input,output,peek)
    local trans={}
    trans["init"]=function(input,output)
        local c=input()
        if(c==nil) then
            return "stop"
        elseif(isSpace(c)) then
            return "init"
        elseif(c=='-') then
            return "comment_ping1"
        elseif(c=="'") then
            output(c)
            return "single_quote"
        elseif(c=='"') then
            output(c)
            return "double_quote"
        else
            output(c)
            return "normal"
        end
    end
    trans["comment_ping1"]=function(input,output,peek)
        local c=peek()
        if(c==nil) then
            return "stop"
        elseif(c=='-') then
            input()
            return "comment_ping2"
        else
            output('-')
            return "normal"
        end
    end
    trans["comment_ping2"]=function(input,output)
        local c=input()
        if(c==nil) then
            return "stop"
        elseif(c=='[') then
            return "comment_ping3"
        else
            return "comment"
        end
    end
    trans["comment_ping3"]=function(input,output)
        local c=input()
        if(c==nil) then
            return "stop"
        elseif(c=='[') then
            return "long_comment"
        else
            return "comment"
        end
    end
    trans["comment"]=function(input,output)
        local c=input()
        if(c==nil) then
            return "stop"
        elseif(c=="\n") then
            return "normal"
        else
            return "comment"
        end
    end
    trans["long_comment"]=function(input,output)
        local c=input()
        if(c==nil) then
            return "stop"
        elseif(c==']') then
            return "endcomment_ping"
        else
            return "long_comment"
        end
    end
    trans["endcomment_ping"]=function(input,output)
        local c=input()
        if(c==nil) then
            return "stop"
        elseif(c==']') then
            return "normal"
        else
            return "long_comment"
        end
    end
    trans["single_quote"]=function(input,output)
        local c=input()
        if(c==nil) then
            return "stop"
        end
        output(c)
        if(c=="'") then
            return "normal"
        else
            return "single_quote"
        end
    end
    trans["double_quote"]=function(input,output)
        local c=input()
        if(c==nil) then
            return "stop"
        end
        output(c)
        if(c=='"') then
            return "normal"
        else
            return "double_quote"
        end
    end
    trans["normal"]=function(input,output)
        local c=input()
        if(c==nil) then
            return "stop"
        elseif(c=='"') then
            output(c)
            return "double_quote"
        elseif(c=="'") then
            output(c)
            return "single_quote"
        elseif(c=='-') then
            return "comment_ping1"
        elseif(isSpace(c)) then
            output(' ')
            return "normal_space"
        elseif(c=='[') then
            output(c)
            trans.lqsz=0
            return "long_quote_ping"
        else
            output(c)
            return "normal"
        end
    end
    trans["normal_space"]=function(input,output)
        local c=input()
        if(c==nil) then
            return "stop"
        elseif(c=='"') then
            output(c)
            return "double_quote"
        elseif(c=="'") then
            output(c)
            return "single_quote"
        elseif(c=='-') then
            return "comment_ping1"
        elseif(isSpace(c)) then
            return "normal_space"
        elseif(c=='[') then
            output(c)
            trans.lqsz=0
            return "long_quote_ping"
        else
            output(c)
            return "normal"
        end
    end
    trans["long_quote_ping"]=function(input,output,peek)
        local c=peek()
        if(c==nil) then
            return "stop"
        end

        if(c=="=") then
            output(input())
            trans.lqsz=trans.lqsz+1
            return "long_quote_ping"
        elseif(c=='[') then
            output(input())
            return "long_quote"
        else
            if(trans.lqsz==0) then
                return "normal_space"
            else -- Just like: [==x
                return "stxerror"
            end
        end
    end
    trans["long_quote"]=function(input,output)
        local c=input()
        if(c==nil) then
            return "stop"
        end
        output(c)
        if(c=="]") then
            trans.lqdt=0
            return "endquote_ping"
        else
            return "long_quote"
        end
    end
    trans["endquote_ping"]=function(input,output)
        local c=input()
        if(c==nil) then
            return "stop"
        end
        output(c)
        if(c=="=") then
            trans.lqdt=trans.lqdt+1
            return "endquote_ping"
        elseif(c=="]") then
            if(trans.lqdt==trans.lqsz) then
                return "normal"
            else
                trans.lqdt=0
                return "endquote_ping"
            end
        else
            return "long_quote"
        end
    end

    return trans
end

local function shrinkFSM(str)
    local trans=GetTrans()
    local out={}
    local cur=0
    local len=str:len()
    local function input()
        if(cur<len) then
            cur=cur+1
            return str:sub(cur,cur)
        else
            return nil
        end
    end
    local function peek()
        if(cur<len) then
            return str:sub(cur+1,cur+1)
        else
            return nil
        end
    end
    local function output(c)
        table.insert(out,c)
    end
    local curState="init"
    while trans[curState] do
        curState=trans[curState](input,output,peek)
    end
    if(curState=="stop") then
        return table.concat(out,"")
    elseif(curState=="stxerror") then
        error("SyntaxError: invalid long string delimiter")
    else
        error("FSMInvalidState: State not found: " .. curState)
    end
end

return shrinkFSM