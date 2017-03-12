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
end

function WebDavServer:get(request) 
    local parts = url.parse_path(request.path)
    print(#parts)
    if #parts ~= 2 then
        return nil
    end
    local project = parts[1]
    local fullFileName = parts[2]
    local fileName,fileExtension = fullFileName:match("(.-)%.(.*)")
    fileExtension = fileExtension:lower()
    
    if fileExtension == "lua" then
        local content = tryReadProjectTab(string.format("%s:%s",project,fileName))
        if content then
            return self:response(200,"OK", content, "Content-Type",'text/lua; charset="utf8"')
        end
    elseif fileName:lower() == "info" and fileExtension == "plist" then
        local content = tryReadLocalFile(project,fullFileName)
        if content then
            return self:response(200,"OK",content,"Content-Type",'text/xml; charset="utf8"')
        end
    end
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
    -- request for root
    if count == 0 then
        table.insert(nodes,{path="/", folder=true})
        for i,name in ipairs(listProjects()) do
            name = parseProjectName(name)
            table.insert(nodes,{path=string.format("/%s/",name), folder=true})
        end
    elseif count > 0 then
        local project = parts[1]
        if count == 1 then
            table.insert(nodes,{path=string.format("/%s/",project), folder=true})
            table.insert(nodes, {path=string.format("/%s/Info.plist",project)})
            for i, name in ipairs(listProjectTabs(project)) do
                table.insert(nodes,{path=string.format("/%s/%s.lua",project,name)})
            end
        else
            return nil
        end
    end
    local builder = XmlBuilder()
    :ns("D")
    :elem("multistatus")
    :attr("xmlns:D","DAV:")
    :push()
    
    for i,node in ipairs(nodes) do
        builder:elem("response"):push()
            builder:elem("href",node.path)
            builder:elem("propstat"):push()
                builder:elem("prop"):push()
                    if node.folder then
                        builder:elem("resourcetype"):push():elem("collection"):pop()
                    end
                    builder:elem("creationdate","2017-02-08T00:23:12+00:00")
                builder:pop()
                builder:elem("status","HTTP/1.1 200 OK")
            builder:pop()
        :pop()
    end
    return self:response(207,"Multi Status",builder:toString(),"Content-Type",'text/xml; charset="utf8"')
end 


