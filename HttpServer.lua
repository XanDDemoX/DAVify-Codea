-- Generic barebones HTTP 1.1 server which implements recieving requests and sending responses  
-- but doesn't implement any actual HTTP methods.
-- https://tools.ietf.org/html/rfc2068

HttpServer = class()

function HttpServer:init(callback,port,timeout,clientTimeout,clientLimit)
    self.callback = callback or function(request) end
    -- automatic is default
    self.port = port or 0
    self.url = ""
    -- 1/6000th of a second i.e 1/100th of a frame. Can't block for too long because it will kill the draw loop.
    self.timeout = timeout or 1/6000
    -- 10 seconds, should be more than enough time to receive a request and send a response for light use
    self.clientTimeout = clientTimeout or 10
    self.clientLimit = clientLimit or 10
    self.running = false
    self.receiving = false
    self.stopAfterRecieve = false
    self.name = "Codea-HTTP/1.1"
    self.debug = false
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
    if client ~= nil then
        self.receiving = true
        -- client connected. Set the timeout.
        client:settimeout(self.clientTimeout)
        
        -- Receive the request's first line
        local requestString = client:receive()
        if requestString then
            -- try receive and parse the rest of the request
            local request = HttpRequest.fromSocket(requestString,client)
            local response
            if request then
                self:debugOutput(request)
                -- check that protocol version is supported
                if request.version ~= "HTTP/1.1" then
                    response = HttpResponse(505)
                else
                    -- request recieved successfully and pass to callback to get the response
                    response = self.callback(request)
                end
            else
                -- failed to parse so 400 bad request 
                response = HttpResponse(400)
            end
            
            response = response or HttpResponse(500) -- if no response then 500
            self:injectHeader(response)
            response:sendHeader(client)
            response:sendContent(client)
            
            self:debugOutput(response)
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
    -- reclaim memory, seccond collectgarbge ensures resurrected objects are collected 
    -- (i.e objects which need finalising with __gc)
    collectgarbage()
    collectgarbage()
end

function HttpServer:debugOutput(obj)
    if not self.debug then return end
    if type(obj) == "table" and obj.is_a then
        
        if obj:is_a(HttpRequest) then
            print(obj:toString())
        elseif obj:is_a(HttpGetResponse) then
            print(obj:getHeader())
        elseif obj:is_a(HttpResponse) then
            print(obj:toString())
        end
    end
end

function HttpServer:injectHeader(response)
    local header = response.header
    table.insert(header,"Cache-Control")
    table.insert(header,"no-cache")
    
    table.insert(header,"Connection")
    table.insert(header,"close")
    
    table.insert(header,"Date")
    table.insert(header,os.date("!%a, %d %b %Y %X GMT"))--utc
    
    table.insert(header,"Server")
    table.insert(header,self.name)
    return header
end

