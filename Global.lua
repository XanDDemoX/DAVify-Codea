socket = require("socket")
url = socket.url

function tryReadProjectTab(key)
    print(key)
    local result, content = xpcall(readProjectTab,function()end, key)
    return result and content or nil
end

function tryReadLocalFile(project,fileName)
    local path = string.format("%s/Documents/%s.codea/%s",os.getenv("HOME"),project,fileName)
    local stream = io.open(path,"r")
    if not stream then return nil end
    local content = stream:read("*all")
    stream:close()
    return content
end
