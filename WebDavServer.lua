-- https://tools.ietf.org/html/rfc4918
-- https://tools.ietf.org/html/rfc2616
-- http://www.webdav.org/specs/rfc3648.html
-- http://stackoverflow.com/questions/10144148/example-of-a-minimal-request-response-cycle-for-webdav

WebDavServer = class(HttpServer)

function WebDavServer:init(...)
    HttpServer.init(self, function(request)
        if request.method == "GET" then
            return self:get(request)
        elseif request.method == "OPTIONS" then
            return self:options(request)
        elseif request.method == "PROPFIND" then
            return self:propFind(request)
        else
            return self:error(405,"Method Not Allowed")
        end
    end,...)
    self.name = "Codea-WebDav-HTTP/1.1"
    self.date = os.date("%Y-%m-%dT%H:%M:%S+00:00")
end

function WebDavServer:get(request) 
    local parts = url.parse_path(request.path)
    if #parts ~= 2 then
        return nil
    end
    local project = parts[1]
    local fullFileName = parts[2]
    local fileName,fileExtension = fullFileName:match("(.-)%.(.*)")
    fileExtension = fileExtension:lower()
    local content = tryReadProjectFile(project,fullFileName)
    if content then
        return self:response(200,"OK",content,"Content-Type",'text/xml; charset="utf8"')
    end
    --[[
    if fileExtension == "lua" then
        local content = tryReadProjectTab(string.format("%s:%s",project,fileName))
        if content then
            return self:response(200,"OK", content, "Content-Type",'text/lua; charset="utf8"')
        end
          ]]--
    --elseif fileName:lower() == "info" and fileExtension == "plist" then

   -- end
    return self:error(404,"Not found")
end

function WebDavServer:options(request)
    return self:response(200,"OK","",
    "Allow","OPTIONS, GET",
    "Allow","PROPFIND")
end

--[[
<?xml version="1.0" encoding="utf-8"?>
<D:multistatus xmlns:D="DAV:">
    <D:response>
        <D:href>/</D:href>
        <D:propstat>
            <D:prop>
                <D:resourcetype><D:collection/></D:resourcetype>
                <D:creationdate>2017-02-07T23:41:15+00:00</D:creationdate>
            </D:prop>
            <D:status>HTTP/1.1 200 OK</D:status>
        </D:propstat>
    </D:response>
    <D:response>
        <D:href>/Voxel</D:href>
        <D:propstat>
            <D:prop>
                <D:resourcetype><D:collection/></D:resourcetype>
                <D:creationdate>2017-02-08T00:23:12+00:00</D:creationdate>
            </D:prop>
            <D:status>HTTP/1.1 200 OK</D:status>
        </D:propstat>
    </D:response>
</D:multistatus>
]]--
--removes the collection if present e.g Examples:Flappy -> Flappy
--because listProjectTabs only works for project names not Collection:Project
local function parseProjectName(name)
    local col,proj = name:match("(.-):(.*)")
    return proj or name
end
function WebDavServer:propFind(request)
    local parts = url.parse_path(request.path)
    local count = #parts
    local nodes = {}
    local depth = tonumber(request.header["Depth"]) or 1
    
    -- request for root
    if count == 0 then
        table.insert(nodes,{path="/", folder=true})
        if depth == 1 then
            local folders = listProjects()
            for i,name in ipairs(folders) do
                if not name:find(":") then -- filter out collections for now e.g Examples 
                --name = parseProjectName(name)
                    table.insert(nodes,{path=string.format("/%s/",name), folder=true})
                end
            end
        elseif depth > 1 then
            return nil
        end
    elseif count > 0 then -- no support for paths > 2 
        local isFile = parts[count]:find("%.") ~= nil
        if isFile then
            local project = parts[1]
            local fileName = parts[2]
            local size = tryGetProjectFileSize(project,fileName)
            if not size then
                return self:error(404,"Not found")
            end
            table.insert(nodes,{path=string.format("/%s/%s.lua",project,fileName),size=size})
        else
            local project = parts[1]
            if count == 1 then
                table.insert(nodes,{path=string.format("/%s/",project), folder=true})
                local plistSize = tryGetProjectFileSize(project,"Info.plist")
                if plistSize then
                    table.insert(nodes, {path=string.format("/%s/Info.plist",project), size=plistSize})
                end
                for i, fileName in ipairs(listProjectTabs(project)) do
                    local size = tryGetProjectFileSize(project,string.format("%s.lua",fileName))
                    table.insert(nodes,{path=string.format("/%s/%s.lua",project,fileName),size=size})
                end
            else
                return nil
            end
        end
    end
    local builder = XmlBuilder()
    :ns("D")
    :elem("multistatus")
    :attr("xmlns:D","DAV:")
    :push()
    local date = self.date
    for i,node in ipairs(nodes) do
        builder:elem("response"):push()
            builder:elem("href",node.path)
            builder:elem("propstat"):push()
                builder:elem("prop"):push()
                    builder:elem("creationdate",date)
                    if node.folder then
                        builder:elem("resourcetype"):push():elem("collection"):pop()
                    else
                        builder:elem("getlastmodified",date)
                        if node.size then
                            builder:elem("getcontentlength",node.size)
                        end
                    end
                builder:pop()
                builder:elem("status","HTTP/1.1 200 OK")
            builder:pop()
        :pop()
    end
    return self:response(207,"Multi Status",builder:toString(),
    "Content-Type",'application/xml; charset="utf-8"')
end 


