-- WebDavServer
function setup()
    --if false == false then return end
    print("loading project and asset data ...")
    -- initialise the virtual file system
    -- create the root folder and add root folders for projects and each asset type.
    local folder = FolderNode()
    folder:add(ProjectsFolderNode("Projects"))
    local assets = FolderNode("Assets")
    folder:add(assets)
    assets:add(AssetPackFolderNode(DOCUMENTS))
    assets:add(AssetPackFolderNode(DROPBOX))
    
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
