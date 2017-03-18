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

function FolderNode:canCreateFolder()
    return false
end

function FolderNode:createFolder(name)
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
function FileNode:init(name)
    FileSystemNode.init(self,name)
end

function FileNode:size()
    return 0
end

function FileNode:read()
    return nil
end

function FileNode:write(data)
    return false
end

function FileNode:fullpath()
    if self.folder then
        return string.format("%s/%s",self.folder:fullpath(),self.name)
    end
    return self.name
end

function FileNode:extension()
    return self.name:sub(self.name:find("%.[^%.]*$"))
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

function NativeFileNode:write(data)
    assert(type(data)=="string","'data' must be a string")
    local stream = self:open("w+")
    stream:write(data)
    stream:close()
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

-- projects
ProjectCollectionFolderNode = class(FolderNode)
function ProjectCollectionFolderNode:init(name)
    FolderNode.init(self, name)
end

function ProjectCollectionFolderNode:canCreateFolder()
    return true
end

function ProjectCollectionFolderNode:validFolderName(name)
    
end

function ProjectCollectionFolderNode:createFolder(name)
    if not self:validFolderName(name) then
        return false
    end
    
    local result = xpcall(createProject,function() end,string.format("%s:%s",self.name,name))
    if result then
        self:add(ProjectFolderNode(name))
    end
    return false, result
end

ProjectFolderNode = class(FolderNode)
function ProjectFolderNode:init(name)
    FolderNode.init(self, name)
    for i,tabName in ipairs(listProjectTabs(name)) do
        self:add(ProjectFileNode(string.format("%s.lua",tabName)))
    end
    self:add(ProjectFileNode("Info.plist"))
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

