-- Generic Implementation of a WebDav server for a given virtual file system
-- https://tools.ietf.org/html/rfc2068
-- https://tools.ietf.org/html/rfc4918
-- https://tools.ietf.org/html/rfc2616
-- http://www.webdav.org/specs/rfc3648.html
-- http://stackoverflow.com/questions/10144148/example-of-a-minimal-request-response-cycle-for-webdav
-- http://sabre.io/dav/clients/windows/


WebDavServer = class(HttpServer)

function WebDavServer:init(folder,...)
    assert(type(folder)=="table" and folder.is_a and folder:is_a(FolderNode),
    "'folder' must not be null and derive from FolderNode.")
    
    HttpServer.init(self, function(request)
        local method = request.method
        if method == "GET" then
            return self:get(request)
        elseif method == "HEAD" then
            return self:head(request)
        elseif method == "PUT" then
            return self:put(request)
        elseif method == "MKCOL" then
            return self:mkcol(request)
        elseif method == "MOVE" then
            return self:move(request)
        elseif method == "DELETE" then
            return self:delete(request)
        elseif method == "OPTIONS" then
            return self:options(request)
        elseif method == "PROPFIND" then
            return self:propFind(request)
        elseif method == "PROPPATCH" then
            return self:propPatch(request)
        elseif method == "LOCK" then
            return self:lock(request)
        elseif method == "UNLOCK" then
            return self:unlock(request)
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

function WebDavServer:head(request) 
    local node = self.folder:get(request.path)
    if not node then
        return HttpResponse(404)
    end
    
    if not node:is_a(FileNode) then
        return HttpResponse(405,"","Allow",self:getAllow(node))
    end
    
    return HttpResponse(200)
end

function WebDavServer:put(request)
    local node = self.folder:get(request.path)
    local content = request.body
    if node and node:is_a(FileNode) then
        -- attempt to update the file
        if not node:canWrite() then
            return HttpResponse(403)
        elseif node:write(content) then
            return HttpResponse(204)
        else
            return HttpResponse(500)
        end
    elseif node then
        -- invalid node 
        return HttpResponse(405,"","Allow",self:getAllow(node))
    else
        -- attempt to create the file
        local parentPath,fileName = Path.splitPathAndName(request.path)
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
    local parentPath,folderName = Path.splitPathAndName(path)
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

function WebDavServer:getDestinationServerAndPath(request)
    local destination = request.header["Destination"]
    if destination then
        local server, path = destination:match("([^%s/]-//[^/]-)(/.*)")
        return server and string.format("%s/",server),path
    end
    return nil
end

function WebDavServer:copyNode(source, target, xml)
    local result = true
    if source:is_a(FolderNode) then
        local folder = target:get(source.name)
        if not folder and target:canCreateFolders() and target:canCreateFolder(source.name) then
            folder = target:createFolder(source.name)
        end
        if folder then
            for i,node in ipairs(source:getNodes()) do
                if not self:copyNode(node, folder, xml) then
                    result = false
                end
            end
        end
    elseif source:is_a(FileNode) then
        local file = target:get(source.name)
        if not file and target:canCreateFiles() and target:canCreateFile(source.name) then
            file = target:createFile(source.name)
        end
        if file and file:write(source:read()) then
        else
            result = false
        end
    else
        return false
    end
    return result
end

function WebDavServer:move(request)
    local server, destination = self:getDestinationServerAndPath(request)
    if not server or not destination then 
        return HttpResponse(400)
    end
    -- server to server transfer disabled to avoid implementing a client as well
    if server ~= self.url then
        return HttpResponse(405)
    end
    if request.path == destination then
        return HttpResponse(403)
    end
    local node = self.folder:get(request.path)
    if not node then 
        return HttpResponse(404)
    end
    local overwrite = request.header["Overwrite"] or ""
    local destNode = self.folder:get(destination)
    if overwrite:upper() == "F" and destNode ~= nil then
        return HttpResponse(412)
    end
    if node:is_a(FolderNode) then
        local folder = node.folder
        if not folder:canDeleteFolder(node) then
            return HttpResponse(403)
        end
        
        -- depth must be infinity when moving
        local depth = request.header["Depth"] or "infinity"
        depth = depth:lower()
        if depth ~= "infinity" then
            return HttpResponse(409)
        end
        if not destNode then
            local parentPath,folderName = Path.splitPathAndName(destination)
            local parent = self.folder:get(parentPath)
            if not parent then
                return HttpResponse(409)
            end
            if not parent:canCreateFolders() then
                return HttpResponse(403)
            end
            if parent:canCreateFolder(folderName) then
                local childFolder = parent:createFolder(folderName)
                if childFolder then
                    destNode = childFolder
                else
                    return HttpResponse(500)
                end
            else
                return HttpResponse(422)
            end
        end
        
        local xml = XmlBuilder()
        xml:ns("D")
        :elem("multistatus")
        :attr("xmlns:D","DAV:")
        :push()
        local copied = true
        for i,child in ipairs(node:getNodes()) do
            if not self:copyNode(child,destNode,xml) then
                copied = false
            end
        end
        if copied then -- only delete if all nodes were copied successfully
            folder:deleteFolder(node)
        end
        return HttpResponse(207,xml:toString(),"Content-Type",'application/xml; charset="utf-8"')
    elseif node:is_a(FileNode) then
        local folder = node.folder
        if not folder:canDeleteFile(node) then
            return HttpResponse(403)
        end
        if destNode then
            if destNode:write(node:read()) then
                if folder:deleteFile(node) then
                    return HttpResponse(204)
                end
            end
        else
            local parentPath,fileName = Path.splitPathAndName(destination)
            local parent = self.folder:get(parentPath)
            if not parent then
                return HttpResponse(409)
            end
            if not parent:canCreateFiles() then
                return HttpResponse(403)
            end
            if not parent:canCreateFile(fileName) then
                return HttpResponse(415)
            end
            local file = parent:createFile(fileName)
            if file and file:write(node:read()) then
                if folder:deleteFile(node) then
                    return HttpResponse(201)
                end
            elseif file then
                parent:deleteFile(file)
            end
        end
    end
end

function WebDavServer:delete(request)
    local node = self.folder:get(request.path)
    if not node then
        return HttpResponse(404)
    end
    if node:is_a(FileNode) then
        if node.folder:canDeleteFile(node) then
            if node.folder:deleteFile(node) then
                return HttpResponse(204)
            end
        else
            return HttpResponse(403)
        end
    elseif node:is_a(FolderNode) then
        if node.folder:canDeleteFolder(node) then
            if node.folder:deleteFolder(node) then
                return HttpResponse(204)
            end
        else
            return HttpResponse(403)
        end
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
        -- if the node is not found just return the root. This also just so happens to fix
        -- windows deciding the server doesn't exist because desktop.ini is not found.
        return HttpResponse(200,"","Allow",self:getAllow(self.folder))
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
            xml:elem("href",node:fullpath())
            xml:elem("propstat"):push()
                xml:elem("prop"):push()
                    xml:elem("creationdate", node.created)
                    if node:is_a(FolderNode) then
                        xml:elem("resourcetype"):push():elem("collection"):pop()
                    else
                        xml:elem("getlastmodified", node.modified)
                        xml:elem("getcontentlength", node:size())
                    end
                xml:pop()
                xml:elem("status","HTTP/1.1 200 OK")
            xml:pop()
        :pop()
    end
    return HttpResponse(207,xml:toString(),"Content-Type",'application/xml; charset="utf-8"')
end

function WebDavServer:isWindowsClient(request)
    local userAgent = request.header["User-Agent"] or ""
    return userAgent:lower():find("microsoft-webdav",1,true) ~= nil
end

function WebDavServer:propPatch(request)

    if self:isWindowsClient(request) then
        -- send a fake response to satisfy the two PROPPATCH requests that 
        -- the windows client sends during file creation. We don't care about the properties.
        local node = self.folder:get(request.path)
        if not node then
            return HttpResponse(404)
        end
        if node:is_a(FolderNode) then
            return HttpResponse(405)
        end
        -- observed with wireshark + apache 
        local xml = XmlBuilder()
        :ns("D")
        :elem("multistatus")
        :attr("xmlns:D","DAV:")
        :attr("xmlns:ns1","urn:schemas-microsoft.com:")
        :attr("xmlns:ns0","DAV:")
        :push()
        
        xml:elem("response"):push()
        xml:elem("href",node:fullpath())
        xml:elem("propstat"):push()
        xml:elem("prop"):push()
            local ns = xml:getNamespace()
            xml:ns("ns1")
            xml:elem("Win32CreationTime")
            xml:elem("Win32LastAccessTime")
            xml:elem("Win32LastModifiedTime")
            xml:elem("Win32FileAttributes")
            xml:ns(ns)
        xml:pop()
        xml:elem("status","HTTP/1.1 200 OK")
        return HttpResponse(207,xml:toString(),"Content-Type",'application/xml; charset="utf-8"')
    end
    return HttpResponse(405)
end

function WebDavServer:lock(request)

    local node = self.folder:get(request.path)
    if not node or not node:is_a(FileNode) then
        return HttpResponse(405) 
    end
    
    -- parse properties which need to be sent back
    local body = request.body
    local parser = XmlParser()
    parser:ns("D")
    local lockType = parser:tag(parser:content("locktype",body))
    local lockScope = parser:tag(parser:content("lockscope",body))
    local owner = parser:content("href",parser:content("owner",body))
    local timeout = request.header["Timeout"]
    if not lockType or not lockScope or not owner or not timeout then
        return HttpResponse(400)
    end
    
    -- send a 'legitimate’ response for tempermental clients which can't function without locking. (a.k.a Windows)
    local xml = XmlBuilder()
    xml:ns("D")
    xml:elem("prop"):attr("xmlns:D","DAV:"):push()
    xml:elem("lockdiscovery"):push()
    xml:elem("activelock"):push()
    
    xml:elem("locktype"):push():elem(lockType):pop()
    xml:elem("lockscope"):push():elem(lockScope):pop()
    xml:elem("depth","infinity")
    
    -- ns0 observed with wireshark + apache. Win7/8 compat?
    local ns = xml:getNamespace()
    xml:ns("ns0")
    xml:elem("owner"):push():elem("href",owner):pop()
    xml:ns(ns)
    
    xml:elem("timeout",timeout)
    
    -- using an obviously fake locktoken so it will hopefully be clear that 
    -- it is a forged response from the raw packets alone.
    xml:elem("locktoken"):push():elem("href","opaquelocktoken:01234567-89ab-cdef-0123-456789abcdef"):pop()

    return HttpResponse(200,xml:toString(),
        "Content-Type",'application/xml; charset="utf-8"',
        "Lock-Token","<opaquelocktoken:01234567-89ab-cdef-0123-456789abcdef>"
    )
end

function WebDavServer:unlock(request)
    return HttpResponse(204)
end
