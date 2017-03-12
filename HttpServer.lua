HttpServer = class()

function HttpServer:init(callback,port,timeout,clientTimeout,clientLimit)
    self.callback = callback or function(request) end
    -- automatic is default
    self.port = port or 0
    self.url = ""
    -- 1/6000th of a second i.e 1/100th of a frame. Can't block for too long because it will kill the draw loop.
    self.timeout = timeout or 1/6000
    -- 2 seconds, should be more than enough time to receive a request and send a response for light use
    self.clientTimeout = clientTimeout or 2
    self.clientLimit = clientLimit or 10
    self.running = false
    self.receiving = false
    self.stopAfterRecieve = false
    self.name = "Codea-HTTP/1.1"
    --self.clients = {}
end

function HttpServer:getIp()
    local s = socket.udp() 
    s:setpeername("255.255.255.255","65535") 
    local ip = s:getsockname()
    s:close()
    return ip
end


function HttpServer:start()
    assert(self.socket==nil,"Server is already running")
    local ip = self:getIp()
    -- create a tcp socket instance
    self.socket = socket.tcp()
    -- attempt to bind the port. This shouldn't fail with an automatic port.
    if self.socket:bind("*", self.port) then
        
        -- set the timeout
        self.socket:settimeout(self.timeout)
        
        -- transform tcp master to server
        self.socket:listen(self.clientLimit)
        
        local addr,port = self.socket:getsockname()
         -- set the port so that it is available even when 0 (auto) is specified.
        self.port = port
        self.url = string.format("http://%s:%i/",ip,port)
        self.running = true
    end
    assert(self.running == true, "Error starting server: Could not bind port.")
end

function HttpServer:stop()
    assert(self.socket~=nil, "Server is not running.")
    if self.receiving == true then
        self.stopAfterRecieve = true
        return
    end
    -- close the socket
    self.running = false
    self.socket:close()
    self.socket = nil
end

function HttpServer:update()
    if self.running == false then
        return
    end
    -- wait for and accept a connection from a client 
    local client = self.socket:accept()
    if client == nil then
        return -- timeout so we dont care
    end
    self.receiving = true
    -- client connected. Set the timeout.
    client:settimeout(self.clientTimeout)
    
    -- Receive the request's first line
    local requestString = client:receive()
    if requestString then
        -- try receive and parse the rest of the request
        local request = HttpRequest.fromSocket(requestString,client)
        if request then
            print(request:toString())
            -- check that protocol version is supported
            if request.version ~= "HTTP/1.1" then
                client:send(self:error(505,"HTTP Version Not Supported"))
            else
                -- request recieved successfully and pass to callback to get the response
                local response = self.callback(request) or self:error() -- 500
                if response.status == 207 then -- multistatus send header and content individually
                    client:send(response:getHeader())
                    client:send(response:getContent())
                else -- send full response
                    client:send(response:toString())
                end
            end
        else
            -- send 400 bad request because failed to parse request
            client:send(self:error(400,"Bad Request"):toString())
        end
    else
        -- timeout
    end
    client:close() -- we don't keep connection's alive
    self.receiving = false
    if self.stopAfterRecieve == true then
        self.stopAfterRecieve = false
        self:stop()
    end
end

function HttpServer:response(status,message,content,...)
    assert(status ~= nil, "Status must be supplied")
    assert(message ~= nil, "Status message must be supplied")
    content = content or "" 
    
    local header = {...}
    -- add some standard header fields
    table.insert(header,"Server")
    table.insert(header,self.name)
    
    -- calculate content length 
    --local bytes = {string.byte(content,1,-1)}
    local length = string.len(content)
    if length > 0 then
        table.insert(header,"Content-Length")
        table.insert(header,tostring(length))
        
        table.insert(header,"Cache-Control")
        table.insert(header,"no-cache")
    end
    
    table.insert(header,"Connection")
    table.insert(header,"Close")
    
    local response = HttpResponse(status,message,header,content)
    print(response:toString())
    return response
end

function HttpServer:error(status, message)
    status = status or 500
    message = message or "Internal Server Error"
    return self:response(status,message)
end

