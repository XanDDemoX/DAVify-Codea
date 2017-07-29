-- Generic barebones HTTP 1.1 listener which implements recieving requests and sending responses  
-- but doesn't implement any actual HTTP methods.
-- https://tools.ietf.org/html/rfc2068
HttpRequest = class()
function HttpRequest:init(method,path,version,header,body)
    self.method = method:upper()
    self.path = path
    self.version = version:upper()
    self.header = header
    self.body = body or ""
end

function HttpRequest:toString()
    -- reconstruct the request to a full string
    local str = {self.method," ",self.path," ",self.version,"\r\n"}
    for k,v in pairs(self.header) do
        table.insert(str,k)
        table.insert(str,":")
        table.insert(str,v)
        table.insert(str,"\r\n")
    end
    table.insert(str,"\r\n")
    table.insert(str,self.body)
    return table.concat(str)
end

-- response
HttpResponse = class()
HttpResponse.statuses = packLookup(    
-- success statuses
    200,"OK",
    201,"Created",
    204,"No Content",
    207,"Multi Status",

-- client errors
    400,"Bad Request",
    403,"Forbidden",
    404,"Not Found",
    405,"Method Not Allowed",
    409,"Conflict",
    411,"Length Required",
    412,"Precondition Failed",
    415,"Unsupported Media Type",
    422,"Unprocessable Entity",

-- server errors
    500,"Internal Server Error",
    501,"Not Implemented",
    505,"HTTP Version Not Supported",
    507,"Insufficient Storage"
)

HttpResponse.getFirstLine=function(status,message)
    return string.format("HTTP/1.1 %i %s\r\n", status, 
    message or HttpResponse.statuses[status] or "Unknown Status")
end


function HttpResponse:init(status, content,...)
    assert(status ~= nil, "'status' must be supplied")
    self.status = status
    self.message = HttpResponse.statuses[status] or "Unknown Status"
    self.header = {...}
    self.content = content or ""
    -- calculate content length 
    --local bytes = {string.byte(content,1,-1)}
    local length = string.len(self.content)
    if length > 0 then
        table.insert(self.header,"Content-Length")
        table.insert(self.header,tostring(length))
    end
end

function HttpResponse:getHeader()
    local str = {string.format("HTTP/1.1 %i %s\r\n", self.status, self.message)}
    local header = self.header
    -- construct header 
    for i=1,#header,2 do
        local k,v = header[i],header[i+1]
        table.insert(str,k)
        table.insert(str,": ")
        table.insert(str,tostring(v))
        table.insert(str,"\r\n")
    end
    table.insert(str,"\r\n")
    return table.concat(str)
end

function HttpResponse:getContent()
    return self.content
end

function HttpResponse:sendHeader(client)
    client:send(self:getHeader())
end

function HttpResponse:sendContent(client)
    client:send(self:getContent())
end

function HttpResponse:toString()
    return self:getHeader()..self:getContent()
end

--https://developer.mozilla.org/en-US/docs/Web/HTTP/Basics_of_HTTP/MIME_types/Complete_list_of_MIME_types
MimeType = {}
local extensionToMime = packLookup(
    ".fsh","text/plain",
    ".lua","text/plain",
    ".plist",'application/xml; charset="utf-8"',
    ".png","image/png",
    ".txt",'text/plain',
    ".vsh","text/plain",
    ".xml",'application/xml; charset="utf-8"'
)

MimeType.getByExtension = function(extension)
    assert(type(extension) == "string")
    extension = extension:lower()
    return extensionToMime[extension] or "application/octet-stream"
end

-- a GET response which serves a FileNode
HttpGetResponse = class(HttpResponse)
function HttpGetResponse:init(file)
    assert(type(file)=="table" and file.is_a and file:is_a(FileNode),
    "'file' must not be null and derive from FileNode")
    
    HttpResponse.init(self,200)
    self.file = file
    table.insert(self.header,"Content-Length")
    table.insert(self.header,tostring(file:size()))
    
    -- for now
    table.insert(self.header,"Content-Type")
    table.insert(self.header,MimeType.getByExtension(file:extension()))
end

function HttpGetResponse:getContent()
    return self.file:read()
end

-- server
HttpServer = class()
function HttpServer:init(callback,port,timeout,clientTimeout,clientLimit)
    self.callback = callback or function(request) end
    -- automatic is default
    self.port = port or 0
    self.url = ""
    -- 1/600th of a second i.e 1/10th of a frame. Can't block for too long because it will kill the draw loop.
    self.timeout = timeout or 1/600
    -- 10 seconds, should be more than enough time to receive a request and send a response for light use
    self.clientTimeout = clientTimeout or 10
    self.clientLimit = clientLimit or 10
    self.running = false
    self.receiving = false
    self.stopAfterRecieve = false
    self.name = "Codea-HTTP/1.1"
    self.debug = false
    self.threads = {}
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

-- reads a HttpRequest header and body directly from a socket parsing as it goes along
function HttpServer:receive(request,client)
    -- attempt to parse the request line
    local method,path,version = request:match("(.-) (/.-) (HTTP/.*)")
    if not method or not path or not version then
        return HttpResponse(400) -- give up, couldn't even parse request line
    end
    
    -- sanitise path 
    path = url.unescape(path) -- remove url escaping from path e.g %20 becomes a space
    
    local header = {}
    local body = ""
    local cur = request
    -- read and parse the header
    while cur ~= nil and cur ~= "" do
        cur = client:receive()
        if cur ~= nil and cur ~= "" then
            local i = cur:find(":",1,true)
            if i then
                local name,value = cur:sub(1,i-1),cur:sub(i+1)
                name = trim(name)
                value = trim(value)
                header[name] = value
            else
                return HttpResponse(400)
            end
        end
    end
    if not cur then return end -- timeout
    if header["Content-Length"] then
        -- get and parse the content length (bytes)
        local size = tonumber(header["Content-Length"])
        if size and size > 0 then
            body = client:receive(size) -- read the content (probably needs to be smarter if content is massive)
            if not body then -- timeout
                return nil
            end
        end
    elseif header["Transfer-Encoding"] and header["Transfer-Encoding"]:lower() == "chunked" then
        local chunks = {}
        local status,chunk
        while status ~= "closed" do
            client:settimeout(0)
            -- receive chunk size in hex
            local buffer = {}
            local byte
            repeat
                byte,status = client:receive(1)
                table.insert(buffer,byte)
            until status ~= nil or (buffer[#buffer-1] == "\r" and buffer[#buffer] == "\n")
            local hex = tonumber(table.concat(buffer),16) -- parse hex
            if hex and hex > 0 then
                chunk,status = client:receive(hex) -- receive the chunk
                if chunk then
                    table.insert(chunks,chunk)
                end
            elseif hex == 0 then
                -- receive final newline
                client:receive(2)
                break
            end
            client:settimeout(self.clientTimeout)
            coroutine.yield()
        end
        client:settimeout(self.clientTimeout)
        body = table.concat(chunks)
    else
        -- test for a body by attempting to receive 1 byte on a short timeout
        client:settimeout(0.01)
        local byte = client:receive(1)
        client:settimeout(self.clientTimeout)
        -- if there is more data then send 411 length required
        if byte then
            return HttpResponse(411)
        end
    end
    return HttpRequest(method,path,version,header,body)
end

function HttpServer:accept(client)
    -- client connected. Set the timeout.
    client:settimeout(self.clientTimeout)
        
    -- Receive the request's first line
    local requestString = client:receive()
    if requestString then
        -- try receive and parse the rest of the request
        local request = self:receive(requestString,client)
        local response
        if request then

            if request:is_a(HttpRequest) then
                self:debugOutput(client,request)
                -- check that protocol version is supported
                if request.version ~= "HTTP/1.1" then
                    response = HttpResponse(505)
                else
                    -- request recieved successfully and pass to callback to get the response
                    response = self.callback(request)
                end
            elseif request:is_a(HttpResponse) then
                -- if request is actually a response then an error occured
                response = request
            end
                
            response = response or HttpResponse(500) -- if no response then 500
            self:injectHeader(response)
                
            -- allow the response to determine how the files are actually sent
            response:sendHeader(client)
            response:sendContent(client)
                
            self:debugOutput(client,response)
        end
    else
        -- timeout
    end
    client:close()
end

function HttpServer:update()
    if self.running == false then
        return
    end
    -- run threads
    for client,thread in pairs(self.threads) do
        self.receiving = true
        self:debugOutput(client,"thread resume")
        local success = coroutine.resume(thread)
        local status = coroutine.status(thread)
        self:debugOutput(client,"thread "..status)
        if success == false or status == "dead" then
            self.threads[client] = nil
        end
    end
    local anyAlive = false
    for client,thread in pairs(self.threads) do 
        anyAlive = true
        break
    end
    self.receiving = anyAlive
    -- only stop when all clients disconnected
    if anyAlive == false and self.stopAfterRecieve == true then
        self.stopAfterRecieve = false
        self:stop()
        return
    elseif self.stopAfterRecieve == false then -- accept clients
        -- wait for and accept a connection from a client 
        local client = self.socket:accept()
        if client ~= nil then
            local thread = coroutine.create(function()
                self:accept(client)
            end)
            self.threads[client] = thread
            self:debugOutput(client,"thread create")
        end
    end
    -- reclaim memory, seccond collectgarbge ensures resurrected objects are collected 
    -- (i.e objects which need finalising with __gc)
    collectgarbage()
    collectgarbage()
end

function HttpServer:debugOutput(client,obj)
    if not self.debug then return end
    local str = {}
    local thread = self.threads[client]
    table.insert(str,tostring(client))
    table.insert(str,"\r\n")
    table.insert(str,tostring(thread))
    if obj then
        table.insert(str,"\r\n\r\n")
    end
    if type(obj) == "table" and obj.is_a then
        if obj:is_a(HttpRequest) or obj:is_a(HttpResponse) then
            table.insert(str,obj:toString())
        end
    else
        table.insert(str,tostring(obj))
    end
    print(table.concat(str))
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
