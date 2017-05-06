-- WebDavServer
function setup()
    print("loading project and asset data ...")
    -- initialise the virtual file system
    -- create the root folder and add root folders for projects and each asset type.
    local folder = FolderNode()
    folder:add(ProjectsFolderNode("Projects"))
    folder:add(AssetFolderNode("Models",MODELS))
    folder:add(AssetFolderNode("Music",MUSIC))
    folder:add(AssetFolderNode("Shaders",SHADERS))
    folder:add(AssetFolderNode("Sprites",SPRITES))
    folder:add(AssetFolderNode("Sounds",SOUNDS))
    folder:add(AssetFolderNode("Text",TEXT))
    
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
