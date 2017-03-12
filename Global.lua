socket = require("socket")
url = socket.url

function tryReadProjectTab(key)
    print(key)
    local result, content = xpcall(readProjectTab,function()end, key)
    return result and content or nil
end

local function formatFilePath(project,fileName)
    return string.format("%s/Documents/%s.codea/%s",os.getenv("HOME"),project,fileName)
end

function tryReadProjectFile(project,fileName)
    local path = formatFilePath(project,fileName)
    local stream = io.open(path,"r")
    if not stream then return nil end
    local content = stream:read("*all")
    stream:close()
    return content
end

function tryGetProjectFileSize(project, fileName)
    local path = formatFilePath(project,fileName)
    local stream = io.open(path,"r")
    if not stream then return nil end
    local size = stream:seek("end")
    stream:close()
    return size
end
