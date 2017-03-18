socket = require("socket")
url = socket.url

function tryReadProjectTab(key)
    print(key)
    local result, content = xpcall(readProjectTab,function()end, key)
    return result and content or nil
end

function packLookup(...)
    local count = select("#",...)
    assert(count & 1 == 0, "Number of arguments must be even")
    local lookup = {}
    for i=1, count, 2 do
        local key,value = select(i,...)
        lookup[key] = value
    end
    return lookup
end
