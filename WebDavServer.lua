-- https://tools.ietf.org/html/rfc4918
-- https://tools.ietf.org/html/rfc2616
-- http://www.webdav.org/specs/rfc3648.html
-- http://stackoverflow.com/questions/10144148/example-of-a-minimal-request-response-cycle-for-webdav

WebDavServer = class(HttpServer)

function WebDavServer:init(...)
    HttpServer.init(self, function(request)
        if request.method == "PROPFIND" then
            return self:propFind(request.path)
        else
            return self:error(405,"Method Not Allowed")
        end
    end,...)
    self.name = "Codea-WebDav-HTTP/1.1"
end

--[[
<?xml version="1.0" encoding="utf-8"?>
<D:multistatus xmlns:D="DAV:">
    <D:response>
        <D:href>/</D:href>
        <D:propstat>
            <D:prop>
                <D:resourcetype><D:collection/></D:resourcetype>
                <D:creationdate>2017-02-07T23:41:15+00:00</D:creationdate>
            </D:prop>
            <D:status>HTTP/1.1 200 OK</D:status>
        </D:propstat>
    </D:response>
    <D:response>
        <D:href>/Voxel</D:href>
        <D:propstat>
            <D:prop>
                <D:resourcetype><D:collection/></D:resourcetype>
                <D:creationdate>2017-02-08T00:23:12+00:00</D:creationdate>
            </D:prop>
            <D:status>HTTP/1.1 200 OK</D:status>
        </D:propstat>
    </D:response>
</D:multistatus>
]]--
function WebDavServer:propFind(path)
    local builder = XmlBuilder()
    :ns("D")
    :elem("multistatus")
    :attr("xmlns:D","DAV:")
    :push()
    if path == "/" then
        local folders = {"/","/Test/"}
        for i,folder in ipairs(folders) do
            builder:elem("response")
            :push()
                :elem("href",folder)
                :elem("propstat")
                :push()
                    :elem("prop")
                    :push()
                        :elem("resourcetype")
                        :push()
                            :elem("collection")
                        :pop()
                        :elem("creationdate","2017-02-08T00:23:12+00:00")
                    :pop()
                    :elem("status","HTTP/1.1 200 OK")
                :pop()
            :pop()
        end
        return self:response(207,"Multi Status",builder:toString(),"Content-Type",'text/xml; charset="utf8"')
    else
        
    end
end 


