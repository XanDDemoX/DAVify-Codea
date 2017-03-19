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
        local method = request.method
        if method == "GET" then
            return self:get(request)
        elseif method == "PUT" then
            return self:put(request)
        elseif method == "MKCOL" then
            return self:mkcol(request)
        elseif method == "OPTIONS" then
            return self:options(request)
        elseif method == "PROPFIND" then
            return self:propFind(request)
        else
            local node = self.folder:get(request.path)
            if not node then
                return HttpResponse(404)
            end
            return HttpResponse(501,"","Allow",self:getAllow(node)) -- not implemented
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
        return HttpResponse(405,"","Allow",self:getAllow(node))
    end
    
    return HttpGetResponse(node)
end

function WebDavServer:put(request)
    local node = self.folder:get(request.path)
    local content = request.body
    if node and node:is_a(FileNode) then
        -- attempt to update the file
        if not node:canWrite() then
            return HttpResponse(403)
        elseif node:write(content) then
            return HttpResponse(200)
        else
            return HttpResponse(500)
        end
    elseif node then
        -- invalid node 
        return HttpResponse(405,"","Allow",self:getAllow(node))
    else
        -- attempt to create the file
        local parts = url.parse_path(request.path)
        local fileName = parts[#parts]
        table.remove(parts)
        table.insert(parts,1,"")
        local parentPath = table.concat(parts,"/")
        local parent = self.folder:get(parentPath)
        if not parent then
            return HttpResponse(404)
        end
        if not parent:canCreateFiles() then
            return HttpResponse(403)
        end
        if not parent:canCreateFile(fileName) then
            return HttpResponse(415)
        end
        local file = parent:createFile(fileName)
        if file and file:write(content) then
            return HttpResponse(201)
        elseif file then
            parent:deleteFile(file)
        end
        return HttpResponse(500)
    end
end

-- https://msdn.microsoft.com/en-us/library/aa142923(v=exchg.65).aspx
function WebDavServer:mkcol(request)
    local path = request.path
    local node = self.folder:get(path)
    if node then
        return HttpResponse(405,"","Allow",self:getAllow(node)) -- folder already exists
    end
    local parts = url.parse_path(path)
    local folderName = parts[#parts]
    
    table.remove(parts)
    table.insert(parts,1,"")
    local parentPath = table.concat(parts,"/")
    local parent = self.folder:get(parentPath)
    if not parent then
        return HttpResponse(409,"Parent must be created before child.") -- conflict parent must be created first
    end
    if not parent:canCreateFolders() then
        return HttpResponse(403)
    end
    if parent:canCreateFolder(folderName) then
        if parent:createFolder(folderName) then
            return HttpResponse(201)
        else
            return HttpResponse(409,"Collection already exists.")
        end
    else
        return HttpResponse(422)
    end 
end

function WebDavServer:getAllow(node)
    local methods = {"OPTIONS", "PROPFIND"}
    if node:is_a(FileNode) then
        table.insert(methods,"GET")
        if node:canWrite() then
            table.insert(methods,"PUT")
        end
    elseif node:is_a(FolderNode) then
        if node:canCreateFolders() then
            table.insert(methods,"MKCOL")
        end
        if node:canCreateFiles() then
            table.insert(methods,"PUT")
        end
    end
    return table.concat(methods,", ")
end

function WebDavServer:options(request)
    local node = self.folder:get(request.path)
    if not node then
        return HttpResponse(404)
    end
    return HttpResponse(200,"","Allow",self:getAllow(node))
end

function WebDavServer:propFind(request)
    local node = self.folder:get(request.path)
    if not node then
        return HttpResponse(404)
    end
    
    local depth = tonumber(request.header["Depth"])
    if depth ~= 0 and depth ~= 1 then
        -- no support for depth infinity
        return HttpResponse(405,"","Allow",self:getAllow(node),"Allow-Depth","0,1") 
    end

    local nodes = {node}
    if depth == 1 then
        if node:is_a(FolderNode) then
            for k,child in ipairs(node:getNodes()) do
                table.insert(nodes,child)
            end
        else
            return HttpResponse(405,"","Allow",self:getAllow(node),"Allow-Depth","0")
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
