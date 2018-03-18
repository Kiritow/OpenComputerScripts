-- bundle: command line tool for bundling files

local component=require("component")
local shell=require("shell")
require("libbundle")

local args,opts=shell.parse(...)
local argc=#args

if(argc<1 or (opts.d==nil and argc<2)) then
    print("Usage: bundle [-d] <bundled file> [<input file>, ...]")
    return
end

if(opts.d~=nil) then
    Unbundle(args[1])
else
    local t={}
    for i=2,argc,1 do 
        table.insert(t,args[i])
    end
    Bundle(t,args[1])
end