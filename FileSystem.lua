-- base for all file system nodes
FileSystemNode = class()
function FileSystemNode:init(name)
    self.name = name
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
    return false
end

function FolderNode:createFolder(name)
    return nil
end

function FolderNode:canCreateFiles()
    return false
end

function FolderNode:canCreateFile(name)
    return false
end

function FolderNode:createFileNode(name)
    return nil
end

function FolderNode:createFile(name)
    assert(self:canCreateFile(name))
    local file = self:createFileNode(name)
    if file:write("") then
        self:add(file)
        return file
    end
    return nil
end

function FolderNode:canDeleteFiles()
    return true
end

function FolderNode:deleteFile(file)
    assert(type(file) == "table" and file.is_a and file:is_a(FileNode),
    "'file' must not be null and derive from FileNode")
    assert(self.nodes[file.name]==file,"'file' is not a child of this node")
    if file:delete() then
        self:remove(file)
        return true
    end
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
    elseif typ == "string" then
        local n = self.nodes[node]
        assert(n~=nil,"Node does not exist.")
        self.nodes[node] = nil
        n.folder = nil
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
FileNode.getFileName=function(name)
    assert(type(name)=="string","'name' must be a non null string")
    local idx = name:find("%.[^%.]*$")
    if idx then
        return name:sub(1,idx-1)
    end
    return name
end
FileNode.getExtension=function(name)
    assert(type(name)=="string","'name' must be a non null string")
    local idx = name:find("%.[^%.]*$")
    if idx then
        return name:sub(idx)
    end
    return ""
end
function FileNode:init(name)
    FileSystemNode.init(self,name)
end

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
    return FileNode.getExtension(self.name)
end

function FileNode:fileName()
    return FileNode.getFileName(self.name)
end

function FileNode:exists()
    return false
end

-- specific implementations for reading/writing Codea's project data

-- Native file base class which implements io in Codeas documents folder.
-- specialisations can override the nativePath function to read / write from other locations
-- paths to native files should not be stores as a fixed variable so that it can vary for moves and renames etc.
NativeFileNode = class(FileNode)
function NativeFileNode:init(name)
    FileNode.init(self, name)
end

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
ProjectCollectionFolderNode = class(FolderNode)
function ProjectCollectionFolderNode:init(name)
    FolderNode.init(self, name)
end

function ProjectCollectionFolderNode:canCreateFolders()
    return true
end

function ProjectCollectionFolderNode:canCreateFolder(name)
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

function ProjectFolderNode:canCreateFile(name)
    assert(type(name)=="string")
    if not name:find("%.") then
        return false
    end
    local ext = FileNode.getExtension(name):lower()
    return ext == ".lua"
end

function ProjectFolderNode:createFileNode(name)
    return ProjectFileNode(name)
end

function ProjectFolderNode:createFile(name)
    assert(self:canCreateFile(name))
    local tabName = FileNode.getFileName(name)
    local result = xpcall(saveProjectTab,function() end,string.format("%s:%s",self.name,tabName),"")
    if result then 
        local file = ProjectFileNode(name)
        self:add(file)
        return file
    end
    return nil
end

ProjectFileNode = class(NativeFileNode)
function ProjectFileNode:init(name)
    NativeFileNode.init(self, name)
end

function ProjectFileNode:nativePath()
    local colName = self.folder.folder.name
    local projName = self.folder.name
    if colName == "Documents" then
        return string.format("%s/Documents/%s.codea/%s",os.getenv("HOME"),projName,self.name)
    else
        return string.format("%s/Documents/%s.collection/%s.codea/%s",os.getenv("HOME"),colName,projName,self.name)
    end
end

function ProjectFileNode:tabName()
    return string.format("%s:%s",self.folder.name,self:fileName())
end

function ProjectFileNode:canDelete()
    return self.name:lower() == "info.plist"
end

function ProjectFileNode:delete()
    assert(self:canDelete())
    local result = xpcall(saveProjectTab,function() end,self:tabName())
    return result
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
function ShaderFileNode:init(name)
    NativeFileNode.init(self, name)
end

function ShaderFileNode:nativePath()
    return string.format("%s/Documents/%s.shader/%s",os.getenv("HOME"),self.folder.name,self.name)
end

-- asset
AssetFolderNode = class(FolderNode)
function AssetFolderNode:init(name)
    FolderNode.init(self,name)
end

function AssetFolderNode:canCreateFiles()
    return true
end

function AssetFolderNode:canCreateFile(name)
    return true
end

function AssetFolderNode:createFileNode(name)
    return NativeFileNode(name)
end


