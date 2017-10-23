local function do_check(x, expected_type)
    if (type(x) ~= expected_type) then
        error(expected_type .. " expected, got " .. type(x))
    end
end

function checknumber(n)
    do_check(n, "number")
end

function checkstring(n)
    do_check(n, "string")
end

function checknil(n)
    do_check(n, "nil")
end

function checkbool(n)
    do_check(n, "boolean")
end

function checkuserdata(n)
    do_check(n, "userdata")
end

function checkfunc(n)
    do_check(n, "function")
end

function checktable(n)
    do_check(n, "table")
end
