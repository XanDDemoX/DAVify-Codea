-- sockets
socket = require("socket")
url = socket.url

-- Codea Craft
MODELS = "models"
DOCUMENTS = "Documents"
DROPBOX = "Dropbox"

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

function parseProjectKey(key)
    assert(type(key) == "string")
    local idx = key:find(":",1,true)
    if idx then
        return key:sub(idx+1), key:sub(1,idx-1)
    end
    return key
end

function trim(str)
    if str == nil then return nil end
    return str:gsub("^%s+",""):gsub("%s+$","")
end
