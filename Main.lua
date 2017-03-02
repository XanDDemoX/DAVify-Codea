-- WebDavServer

-- Use this function to perform your initial setup
function setup()
    server = WebDavServer(8080)
    print("starting server...")
    server:start()
    print("server started: "..server.url)
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
end

