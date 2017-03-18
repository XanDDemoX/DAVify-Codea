-- WebDavServer

function setup()
    print("loading project data ...")
    -- initialise the virtual file system
    -- create the root folder
    local folder = FolderNode()
    
    -- create a folder for projects and add all non example projects
    local projects = FolderNode("Projects")
    local documents = ProjectCollectionFolderNode("Documents")
    projects:add(documents)
    for i, name in ipairs(listProjects()) do
        local idx = name:find(":",1,true)
        if idx then
            local colName = name:sub(1,idx-1)
            local projName = name:sub(idx+1)
            local collection = projects:get(colName)
            if not collection then
                collection = ProjectCollectionFolderNode(colName)
                projects:add(collection)
            end
            collection:add(ProjectFolderNode(projName))
        else
            documents:add(ProjectFolderNode(name))
        end
    end
    folder:add(projects)
    
    -- create a folder for shaders and add all shaders in documents 
    local shaders = FolderNode("Shaders")
    for i, name in ipairs(assetList("Documents",SHADERS)) do
        shaders:add(ShaderFolderNode(name))
    end
    folder:add(shaders)
    
    -- create a folder for sprites and add all sprites in documents
    local sprites = FolderNode("Sprites")
    for i, name in ipairs(assetList("Documents",SPRITES)) do
        local imgs = {
            NativeFileNode(string.format("%s.png",name)),
            NativeFileNode(string.format("%s@2x.png",name))
        }
        for i, img in ipairs(imgs) do
            if img:exists() then -- test if the file exists before adding (@2x images may not always be present)
                sprites:add(img)
            end
        end
    end
    folder:add(sprites)
    
    -- create a folder for text assests and add all text assets in documents
    local textAssets = FolderNode("Text")
    for i, name in ipairs(assetList("Documents",TEXT)) do
        textAssets:add(NativeFileNode(string.format("%s.txt",name)))
    end
    folder:add(textAssets)
    
    -- start the server 
    server = WebDavServer(folder, 8080)
    print("starting server...")
    server:start()
    print("server started: "..server.url)
    
    memoryUsage = 0
    parameter.watch("memoryUsage")
    parameter.boolean("SERVER_DEBUG",false,function(value)
        server.debug = value
    end)
end

-- This function gets called once every frame
function draw()
    -- This sets a dark background color 
    background(40, 40, 50)

    -- This sets the line thickness
    strokeWidth(5)

    -- Do your drawing here
    if server then
        server:update()
    end
    
    memoryUsage = string.format("%.2f MB",collectgarbage('count')/1024)
end

