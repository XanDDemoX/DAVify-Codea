Path = {}
Path.splitPathAndName = function(path)
    assert(type(path)=="string","'path' must be a non null string")
    local parts = url.parse_path(path)
    local fileName = parts[#parts]
    table.remove(parts)
    table.insert(parts,1,"")
    return table.concat(parts,"/"), fileName
end

Path.getFileNameNoExtension=function(path)
    assert(type(path)=="string","'path' must be a non null string")
    local idx = path:find("%.[^%.]*$")
    if idx then
        return path:sub(1,idx-1)
    end
    return path
end

Path.getExtension=function(path)
    assert(type(path)=="string","'path' must be a non null string")
    local idx = path:find("%.[^%.]*$")
    if idx then
        return path:sub(idx)
    end
    return ""
end

-- base for all file system nodes
FileSystemNode = class()
function FileSystemNode:init(name)
    self.name = name
    self.created = os.date("!%Y-%m-%dT%X+00:00")
    self.modified = self.created
end

function FileSystemNode:setModified()
    self.modified = os.date("!%Y-%m-%dT%X+00:00")
end

-- implements a folder tree. Paths/Urls to files are case-sensitive.
FolderNode = class(FileSystemNode)
function FolderNode:init(name)
    FileSystemNode.init(self,name)
    self.nodes = {}
end

function FolderNode:canCreateFolders()
    return false
end

function FolderNode:canCreateFolder(name)
    assert(type(name)=="string","'name' must not be null and a string.")
    if not self:canCreateFolders() then
        return false
    end
    return self.nodes[name] == nil
end

function FolderNode:createFolderNode(name)
    return FolderNode(name)
end


function FolderNode:createFolder(name)
    assert(self:canCreateFolder(name))
    local folder = self:createFolderNode(name)
    if folder then
        self:add(folder)
    end
    return folder
end

function FolderNode:canDeleteFolders()
    return false
end

function FolderNode:canDeleteFolder(node)
    assert(type(node) == "table" and node.is_a and node:is_a(FolderNode),
    "'file' must not be null and derive from FolderNode")
    if not self:canDeleteFolders() then
        return false
    end
    return self.nodes[node.name] == node and node:canDelete()
end

function FolderNode:canDelete()
    return false
end

function FolderNode:delete()
    return false
end

function FolderNode:deleteFolder(node)
    assert(type(node) == "table" and node.is_a and node:is_a(FolderNode),
    "'node' must not be null and derive from FolderNode")
    assert(self.nodes[node.name]==node,"'node' is not a child of this node")
    assert(self:canDeleteFolder(node),"'node' cannot be deleted")
    if node:delete() then
        self:remove(node)
        return true
    end
    return false
end

function FolderNode:canCreateFiles()
    return false
end

function FolderNode:canCreateFile(name)
    assert(type(name)=="string")
    if not self:canCreateFiles() then
        return false
    end
    return self.nodes[name]==nil
end

function FolderNode:createFileNode(name)
    return nil
end

function FolderNode:createFile(name)
    assert(self:canCreateFile(name))
    local file = self:createFileNode(name)
    self:add(file)
    return file
end

function FolderNode:canDeleteFiles()
    return false
end

function FolderNode:canDeleteFile(node)
    assert(type(node) == "table" and node.is_a and node:is_a(FileNode),
    "'file' must not be null and derive from FileNode")
    if not self:canDeleteFiles() then
        return false
    end
    return self.nodes[node.name] == node and node:canDelete()
end

function FolderNode:deleteFile(node)
    assert(type(node) == "table" and node.is_a and node:is_a(FileNode),
    "'node' must not be null and derive from FileNode")
    assert(self.nodes[node.name]==node,"'node' is not a child of this node")
    assert(self:canDeleteFile(node),"'node' cannot be deleted")
    if node:delete() then
        self:remove(node)
        return true
    end
    return false
end

function FolderNode:canRenameFiles()
    return false
end

function FolderNode:canRenameFile(node,newName)
    return false
end

function FolderNode:renameFile(node,newName)
    return false
end

function FolderNode:getNodes()
    local nodes = {}
    for k, node in pairs(self.nodes) do
        table.insert(nodes, node)
    end
    return nodes
end

function FolderNode:hasNodes()
    for k,v in pairs(self.nodes) do
        return true
    end
    return false
end

function FolderNode:add(node)
    assert(type(node) == "table" and node.is_a and node:is_a(FileSystemNode),
    "'node' must not be null and derive from FileSystemNode.")
    assert(self.nodes[node.name] == nil,string.format("Node '%s' already exists.",node.name))
    self.nodes[node.name] = node
    node.folder = self
    self:setModified()
    return self
end

function FolderNode:remove(node)
    local typ = type(node)
    local isNode = typ == "table" and node.is_a and node:is_a(FileSystemNode)
    assert(isNode or typ=="string","'node' type must be string or derive from FileSystemNode")
    assert(self:hasNodes(),"No nodes")
    if isNode then
        local item = self.nodes[node.name]
        assert(item == node,"Node is not a child of this node.")
        self.nodes[node.name] = nil
        node.folder = nil
        self:setModified()
    elseif typ == "string" then
        local n = self.nodes[node]
        assert(n~=nil,"Node does not exist.")
        self.nodes[node] = nil
        n.folder = nil
        self:setModified()
    end
end

-- gets a node using a url
function FolderNode:get(path)
    assert(path ~= nil, "'path' must not be null.")
    if type(path) == "string" then
        path = url.parse_path(path)
    end
    if #path == 0 then 
        return self
    end
    -- get the node for the first part of the path
    local node = self.nodes[path[1]]
    if node == nil or #path == 1 then
        return node -- found node or 
    end
    if not node:hasNodes() then -- avoid recursing if no child nodes
        return nil
    end
    table.remove(path,1)
    return node:get(path)
end

function FolderNode:fullpath()
    if self.folder then 
        local folder = self.folder:fullpath()
        return string.format("%s%s%s",folder, folder == "/" and "" or "/",self.name)
    elseif self.name then
        return self.name
    else
        return "/"
    end
end


-- interface to provide generic storage
FileNode = class(FileSystemNode)
function FileNode:size()
    return 0
end

function FileNode:read()
    return nil
end

function FileNode:canWrite()
    return false
end

function FileNode:write(data)
    return false
end

function FileNode:canDelete()
    return false
end

function FileNode:delete()
    return false
end

function FileNode:fullpath()
    if self.folder then
        return string.format("%s/%s",self.folder:fullpath(),self.name)
    end
    return self.name
end

function FileNode:extension()
    return Path.getExtension(self.name)
end

function FileNode:fileName()
    return Path.getFileNameNoExtension(self.name)
end

function FileNode:exists()
    return false
end

-- specific implementations for reading/writing Codea's project data

-- Native file base class which implements io in Codeas documents folder.
-- specialisations can override the nativePath function to read / write from other locations
-- paths to native files should not be stores as a fixed variable so that it can vary for moves and renames etc.
NativeFileNode = class(FileNode)
function NativeFileNode:nativePath()
    return string.format("%s/Documents/%s",os.getenv("HOME"),self.name)
end

function NativeFileNode:open(...)
    local path = self:nativePath()
    assert(path~=nil)
    return assert(io.open(path,...))
end

function NativeFileNode:size()
    local stream = self:open("r")
    local size = stream:seek("end")
    stream:close()
    return size
end

function NativeFileNode:read()
    local stream = self:open("r")
    local content = stream:read("*all")
    stream:close()
    return content
end

function NativeFileNode:canWrite()
    return true
end

function NativeFileNode:write(data)
    assert(type(data)=="string","'data' must be a string")
    local result, stream = xpcall(self.open,function()end,self,"w+")
    if stream then
        stream:write(data)
        stream:close()
        self:setModified()
    end
    return result
end

function NativeFileNode:exists()
    local path = self:nativePath()
    assert(path~=nil)
    local stream = io.open(path,"r")
    if stream then
        stream:close()
        return true
    end
    return false
end

function NativeFileNode:canDelete()
    return true
end

function NativeFileNode:delete()
    local path = self:nativePath()
    assert(path ~= nil)
    return os.remove(path) ~= nil
end

-- projects
ProjectsFolderNode = class(FolderNode)
function ProjectsFolderNode:init(name)
    FolderNode.init(self,name)
    local documents = ProjectCollectionFolderNode("Documents")
    self:add(documents)
    for i, key in ipairs(listProjects()) do
        local projName,colName = parseProjectKey(key)
        if colName then
            local collection = self:get(colName)
            if not collection then
                collection = ProjectCollectionFolderNode(colName)
                self:add(collection)
            end
            collection:add(ProjectFolderNode(projName))
        else
            documents:add(ProjectFolderNode(projName))
        end
    end
end
function ProjectsFolderNode:canCreateFolders()
    return true
end

function ProjectsFolderNode:createFolderNode(name)
    return ProjectCollectionFolderNode(name)
end

function ProjectsFolderNode:canDeleteFolders()
    return true
end

function ProjectsFolderNode:canDeleteFolder(node)
    assert(type(node) == "table" and node.is_a and node:is_a(FolderNode))
    assert(self.nodes[node.name] == node)
    return not node:hasNodes() and node.name ~= "Documents"
end

function ProjectsFolderNode:deleteFolder(node)
    assert(self:canDeleteFolder(node))
    self:remove(node)
    return true
end

ProjectCollectionFolderNode = class(FolderNode)
function ProjectCollectionFolderNode:canDeleteFolders()
    return true
end

function ProjectCollectionFolderNode:canCreateFolders()
    return true
end

function ProjectCollectionFolderNode:canCreateFolder(name)
    if not FolderNode.canCreateFolder(self,name) then
        return false
    end
    for i,key in ipairs(listProjects()) do
        local projName,colName = parseProjectKey(key)
        if projName == name then
            return false
        end
    end
    return true
end

function ProjectCollectionFolderNode:createFolder(name)
    assert(self:canCreateFolder(name))
    local result = xpcall(createProject,function() end,string.format("%s:%s",self.name,name))
    if result then
        local folder = ProjectFolderNode(name)
        self:add(folder)
        return folder
    end
    return nil
end

ProjectFolderNode = class(FolderNode)
function ProjectFolderNode:init(name)
    FolderNode.init(self, name)
    for i,tabName in ipairs(listProjectTabs(name)) do
        self:add(ProjectFileNode(string.format("%s.lua",tabName)))
    end
    self:add(ProjectFileNode("Info.plist"))
end

function ProjectFolderNode:canCreateFiles()
    return true
end

function ProjectFolderNode:canDeleteFiles()
    return true
end

function ProjectFolderNode:canCreateFile(name)
    if not FolderNode.canCreateFile(self,name) then
        return false
    end
    return Path.getExtension(name) == ".lua" or name == "Info.plist"
end

function ProjectFolderNode:createFileNode(name)
    return ProjectFileNode(name)
end

function ProjectFolderNode:readInfoXml()
    return Xml.parse(self:get("Info.plist"):read())
end

function ProjectFolderNode:writeInfoXml(xml)
    local builder = XmlBuilder(true, { minIndentDepth=1 }) -- pretty print similar to Codea
    xml:emit(builder)
    return self:get("Info.plist"):write(builder:toString())
end

function ProjectFolderNode:saveTab(tabName,content)
    -- read plist xml before saveProjectTab so that buffer order can be synchronised  
    -- so that it contains the right tabs whilst keeping the existing tabs in the user specified order
    local xml = self:readInfoXml()
    local result = xpcall(saveProjectTab,function() end, string.format("%s:%s",self.name,tabName),content or nil)
    if not result then
        return false
    end
    -- get the buffer order array element
    local bufferOrder = xml:node("plist"):node("dict"):after(function(node)
        return node:name() == "key" and node:value() == "Buffer Order"
    end)
    
    if bufferOrder == XmlNode.null then
        return true
    end
    -- ammend the buffer order if required. we don't perform a full sync because
    -- it would corrupt the tab order in a multi-file copy scenario.
    local node = bufferOrder:query(function(node) return node:value() == tabName end)
    if content and node == XmlNode.null then
        bufferOrder:add(XmlNode("string",tabName))
    elseif not content and node ~= XmlNode.null then
        bufferOrder:remove(node)
    end
    return self:writeInfoXml(xml)
end

function ProjectFolderNode:createFile(name)
    assert(self:canCreateFile(name))
    if name ~= "Info.plist" and name ~= "Main.lua" then
        if not self:saveTab(Path.getFileNameNoExtension(name),"") then 
            return nil
        end
    end
    return FolderNode.createFile(self,name)
end

function ProjectFolderNode:canDelete()
    return hasProject(string.format("%s:%s",self.folder.name,self.name))
end

function ProjectFolderNode:delete()
   assert(self:canDelete())
   local result = xpcall(deleteProject,function() end,string.format("%s:%s",self.folder.name,self.name))
   return result
end

function ProjectFolderNode:canRenameFiles()
    return true
end

function ProjectFolderNode:canRenameFile(node,newName)
    assert(self.nodes[node.name] == node)
    return node ~= self:get("Info.plist") and 
    node ~= self:get("Main.lua") and
    Path.getExtension(newName) == ".lua" and
    self:canCreateFile(newName) and 
    self:canDeleteFile(node)
end

function ProjectFolderNode:renameFile(node, newName)
    assert(self:canRenameFile(node,newName))
    local xml = self:readInfoXml()
    local bufferOrder = xml:node("plist"):node("dict"):after(function(node)
        return node:name() == "key" and node:value() == "Buffer Order"
    end)
    local newTabName = Path.getFileNameNoExtension(newName)
    assert(bufferOrder ~= XmlNode.null)
    local oldTabName = node:fileName()
    local entry = bufferOrder:query(function(n) return n:value() == oldTabName end)
    assert(entry ~= XmlNode.null)
    local result = xpcall(saveProjectTab,function()end,string.format("%s:%s",self.name,newTabName),node:read())
    if result then
        entry:value(newTabName)
        return FolderNode.createFile(self,newName) and self:writeInfoXml(xml) and self:deleteFile(node)
    end
    return false
end

function ProjectFolderNode:getNodes()
    local nodes = FolderNode.getNodes(self)
    -- force Info.plist to bottom so that the tab order is preserved when copying / moving the project
    table.sort(nodes,function(x,y)
        if x.name == "Info.plist" then
            return false
        elseif y.name == "Info.plist" then
            return true
        end
        return x.name < y.name
    end)
    return nodes
end

ProjectFileNode = class(NativeFileNode)
function ProjectFileNode:nativePath()
    local colName = self.folder.folder.name
    local projName = self.folder.name
    if colName == "Documents" then
        return string.format("%s/Documents/%s.codea/%s",os.getenv("HOME"),projName,self.name)
    else
        return string.format("%s/Documents/%s.collection/%s.codea/%s",os.getenv("HOME"),colName,projName,self.name)
    end
end

function ProjectFileNode:write(data)
    -- 'Deleted' plist restore, avoid writing 0 bytes.
    if data == "" and (self.name == "Info.plist" or self.name == "Main.lua") then
        return true
    end
    return NativeFileNode.write(self,data)
end

function ProjectFileNode:tabName()
    return string.format("%s:%s",self.folder.name,self:fileName())
end

function ProjectFileNode:canDelete()
    return true
end

function ProjectFileNode:delete()
    assert(self:canDelete())
    -- Nerver actually delete the .plist with os.remove because it cannot be recreated. 
    -- If it is deleted then listProjectTabs, saveProjectTab and opening/running the project will error.
    -- The only fix is to delete the project with deleteProject.
    if self.name ~= "Info.plist" and self.name ~= "Main.lua" then
        return self.folder:saveTab(self:fileName())
    end
    return true
end

-- shader
ShaderFolderNode = class(FolderNode)
function ShaderFolderNode:init(name)
    FolderNode.init(self, name)
    self:add(ShaderFileNode("Fragment.fsh"))
    self:add(ShaderFileNode("Info.plist"))
    self:add(ShaderFileNode("Vertex.vsh"))
end

ShaderFileNode = class(NativeFileNode)
function ShaderFileNode:canDelete()
    return false
end

function ShaderFileNode:delete()
    return false
end

function ShaderFileNode:nativePath()
    return string.format("%s/Documents/%s.shader/%s",os.getenv("HOME"),self.folder.name,self.name)
end

-- assets
AssetFolderNode = class(FolderNode)
function AssetFolderNode:init(name,assetType)
    FolderNode.init(self,name)
    self.assetType = assetType
    local assets = assetList("Documents",assetType)
    if assetType == SHADERS then
        for i, key in ipairs(assets) do
            self:add(ShaderFolderNode(key))
        end
    elseif assetType == SPRITES then
        for i, key in ipairs(assets) do
            local imgs = {
                NativeFileNode(string.format("%s.png",key)),
                NativeFileNode(string.format("%s@2x.png",key)),
                NativeFileNode(string.format("%s.pdf",key))
            }
            for i, img in ipairs(imgs) do
                -- test if the file exists before adding (@2x images may not always be present)
                if img:exists() then 
                    self:add(img)
                end
            end
        end
    elseif assetType == TEXT then
        for i, key in ipairs(assets) do
            self:add(NativeFileNode(string.format("%s.txt",key)))
        end
    end
end

function AssetFolderNode:canCreateFiles()
    return self.assetType == SPRITES or self.assetType == TEXT
end

function AssetFolderNode:canDeleteFiles()
    return self.assetType == SPRITES or self.assetType == TEXT
end

function AssetFolderNode:createFileNode(name)
    return NativeFileNode(name)
end
