XmlParser = class()
function XmlParser:init()
    self.prefix =""
end

function XmlParser:ns(prefix)
    if prefix then
        self.prefix = string.format("%s:",prefix)
    else
        self.prefix = ""
    end
end

function XmlParser:tag(xml)
    if not xml then
        return
    end
    return xml:match("<"..self.prefix.."([^%s/>]+)")
end

function XmlParser:content(elem,xml)
    if not xml then
        return
    end
    local _,elemStart = xml:find(string.format("<%s%s[^>]->",self.prefix,elem))
    local elemEnd = xml:find(string.format("</%s%s>",self.prefix,elem))
    if not elemStart or not elemEnd then
        return
    end
    return xml:sub(elemStart+1,elemEnd-1)
end

-- https://github.com/Cluain/Lua-Simple-XML-Parser/blob/master/xmlSimple.lua
function XmlParser:escape(value)
    value = string.gsub(value, "&", "&amp;") -- '&' -> "&amp;"
    value = string.gsub(value, "<", "&lt;") -- '<' -> "&lt;"
    value = string.gsub(value, ">", "&gt;") -- '>' -> "&gt;"
    value = string.gsub(value, '"', "&quot;") -- '"' -> "&quot;"
    value = string.gsub(value, "([^%w%&%;%p%\t% ])",
        function(c)
            return string.format("&#x%X;", string.byte(c))
        end)
    return value
end

function XmlParser:unescape(value)
    value = string.gsub(value, "&#x([%x]+)%;",
        function(h)
            return string.char(tonumber(h, 16))
        end)
    value = string.gsub(value, "&#([0-9]+)%;",
        function(h)
            return string.char(tonumber(h, 10))
        end)
    value = string.gsub(value, "&quot;", '"')
    value = string.gsub(value, "&apos;", "'")
    value = string.gsub(value, "&gt;", ">")
    value = string.gsub(value, "&lt;", "<")
    value = string.gsub(value, "&amp;", "&")
    return value
end

function XmlParser:parse(xml)
    local stack = {}
    local cur = XmlNode()
    table.insert(stack, cur)
    local i = 1
    while true do
        local j, k, start, name, args, empty = xml:find("<([%/!?]?)([%w_:]+)(.-)(%/?)>", i)
        if not j then break end
        -- ignore xml and doctype tags
        local ignore = start == "?" or start == "!"
        if not ignore then
            local content = xml:sub(i,j-1)
            if not content:find("^%s*$") then
                stack[#stack]:value((cur:value() or "")..self:unescape(content))
            end
            if start == "" or empty == "/" then
                local node = XmlNode(name)
                -- parse attributes
                string.gsub(args, '(%w+)=(["'.."'])(.-)%2", function(key, _, value)
                    node:attribute(key, self:unescape(value))
                end)
                if start == "" then
                    table.insert(stack, node)
                    cur = node
                else
                    cur:add(node)
                end
            else
                local node = table.remove(stack)
                cur = stack[#stack]
                if not cur then
                    assert(false,"No parent")
                end
                if node:name() ~= name then
                    assert(false, "Closing tag mismatch")
                end
                cur:add(node)
            end
        end
        i = k + 1
    end
    local txt = string.sub(xml,i)
    if #stack > 1 then
        assert(false,"Unclosed tag")
    end
    return cur
end

XmlNode = class()
function XmlNode:init(name)
    self._name = name
end

function XmlNode:name()
    return self._name
end

function XmlNode:value(value)
    if value then
        self._value = value
    end
    return self._value
end

function XmlNode:add(node)
    if not self._nodes then
        self._nodes = {}
    end
    table.insert(self._nodes, node)
end

function XmlNode:attribute(name,value,index)
    if value then
        if not self._attrib then
            self._attrib = {}
        end
        local values = self._attrib[name]
        if not values then
            values = {}
            self._attrib[name] = values
        end
        table.insert(values,value)
    elseif not self._attrib then
        return nil
    else
        local values = self._attrib[name]
        if not values then
            return nil
        end
        if index == "*" then
            local vals = {}
            for i,v in ipairs(values) do
                vals[i]=v
            end
            return vals
        end
        return values[index or 1]
    end
end

function XmlNode:nodes(name)
    if not self._nodes then
        return {}
    end
    if name then
    
    end
    return self._nodes
end
