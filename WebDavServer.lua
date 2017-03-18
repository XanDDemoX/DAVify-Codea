-- Generic Implementation of a WebDav server for a given virtual file system
-- https://tools.ietf.org/html/rfc2068
-- https://tools.ietf.org/html/rfc4918
-- https://tools.ietf.org/html/rfc2616
-- http://www.webdav.org/specs/rfc3648.html
-- http://stackoverflow.com/questions/10144148/example-of-a-minimal-request-response-cycle-for-webdav

WebDavServer = class(HttpServer)

function WebDavServer:init(folder,...)
    assert(type(folder)=="table" and folder.is_a and folder:is_a(FolderNode),
    "'folder' must not be null and derive from FolderNode.")
    HttpServer.init(self, function(request)
        if request.method == "GET" then
            return self:get(request)
        elseif request.method == "OPTIONS" then
            return self:options(request)
        elseif request.method == "PROPFIND" then
            return self:propFind(request)
        else
            return HttpResponse(405,"","Allow","OPTIONS, GET, PROPFIND")
        end
    end,...)
    self.name = "Codea-WebDAV-HTTP/1.1"
    self.date = os.date("!%Y-%m-%dT%X+00:00") --utc
    self.folder = folder
end

function WebDavServer:get(request) 
    
    local node = self.folder:get(request.path)
    if not node then
        return HttpResponse(404)
    end
    
    if not node:is_a(FileNode) then
        return HttpResponse(501)
    end
    
    return HttpGetResponse(node)
end

function WebDavServer:options(request)
    return HttpResponse(200,"","Allow","OPTIONS, GET, PROPFIND")
end

function WebDavServer:propFind(request)
    local depth = tonumber(request.header["Depth"])
    if depth ~= 0 and depth ~= 1 then
        return HttpResponse(501) -- no support for depth infinity
    end
    local node = self.folder:get(request.path)
    if not node then
        return HttpResponse(404)
    end
    local nodes = {node}
    if depth == 1 then
        if node:is_a(FolderNode) then
            for k,child in ipairs(node:getNodes()) do
                table.insert(nodes,child)
            end
        else
            return HttpResonse(501) -- no support for depth 1 for files
        end
    end
    local xml = XmlBuilder()
    :ns("D")
    :elem("multistatus")
    :attr("xmlns:D","DAV:")
    :push()
    local date = self.date
    for i,node in ipairs(nodes) do
        xml:elem("response"):push()
            xml:elem("href",url.escape(node:fullpath()))
            xml:elem("propstat"):push()
                xml:elem("prop"):push()
                    xml:elem("creationdate", date)
                    if node:is_a(FolderNode) then
                        xml:elem("resourcetype"):push():elem("collection"):pop()
                    else
                        xml:elem("getlastmodified", date)
                        xml:elem("getcontentlength", node:size())
                    end
                xml:pop()
                xml:elem("status","HTTP/1.1 200 OK")
            xml:pop()
        :pop()
    end
    return HttpResponse(207,xml:toString(),"Content-Type",'application/xml; charset="utf-8"')
end
