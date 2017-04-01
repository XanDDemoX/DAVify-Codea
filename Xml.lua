Xml = {}
Xml.escape = function(value)
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
Xml.unescape = function(value)
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

function XmlNode:attributes(name)
    if not self._attrib then
        return {}
    end
    if name then
        return self._attrib[name] or {}
    end
    return self._attrib
end

function XmlNode:nodes(name)
    if not self._nodes then
        return {}
    end
    if name then
        local nodes = {}
        for i,node in ipairs(self._nodes) do
            if node:name() == name then
                table.insert(nodes,node)
            end
        end
        return nodes
    end
    return self._nodes
end

function XmlNode:toString(builder)
    assert(type(builder) == "table" and builder.is_a and builder:is_a(XmlBuilder))
    builder:elem(self:name(),self:value())
    for name, values in pairs(self:attributes()) do
        for i,value in ipairs(values) do
            builder:attr(name,value)
        end
    end
    builder:push()
    for i,node in ipairs(self:nodes()) do
        node:toString(builder)
    end
    builder:pop()
end

-- parser 
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
                stack[#stack]:value((cur:value() or "")..Xml.unescape(content))
            end
            if start == "" or empty == "/" then
                local node = XmlNode(name)
                -- parse attributes
                string.gsub(args, '(%w+)=(["'.."'])(.-)%2", function(key, _, value)
                    node:attribute(key, Xml.unescape(value))
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

-- builder which constructs an xml document
XmlBuilder = class()

function XmlBuilder:init()
    self.document = {'<?xml version="1.0" encoding="utf-8"?>'}
    self.element = nil
    self.stack = {}
    self.prefix = ""
    self.namespace = ""
end

function XmlBuilder:getNamespace()
    return self.namespace
end

function XmlBuilder:ns(prefix)
    if prefix then
        self.prefix = string.format("%s:",prefix)
    else
        self.prefix = ""
    end
    self.namespace = prefix or ""
    return self
end

function XmlBuilder:doctype(content)
    table.insert(self.document,2,string.format("<!DOCTYPE %s>",content))
end

local function commitElement(document,elem,partial)
    local opened = false
    if not elem.opened then
        opened = true
        local str = {string.format("<%s%s",elem.prefix,elem.name)}
        if elem.attrib then
            for i,attrib in ipairs(elem.attrib) do
                table.insert(str,string.format(' %s="%s"',attrib.name,attrib.value))
            end
        end
        if not elem.hasChildren and elem.value == nil then
            table.insert(str,"/")
            elem.closed = true
        end
        table.insert(str,">")
        elem.opened = true
        table.insert(document,table.concat(str))
        if partial then
            if not elem.closed then
                return elem
            end
            return nil
        end
    end
    
    if not elem.closed then
        if elem.value ~= nil then
            table.insert(document,string.format("%s</%s%s>",elem.value,elem.prefix,elem.name))
        else
            table.insert(document,string.format("</%s%s>",elem.prefix,elem.name))
        end
        elem.closed = true
        return nil
    end
    if not opened then
        assert(false)
    end
end

function XmlBuilder:elem(name,value)
    assert(name~=nil,"Element name must be supplied.")
    if self.element then
        self.element = commitElement(self.document,self.element)
    end
    local elem = {}
    elem.prefix = self.prefix
    elem.name = name
    elem.value = value
    self.element = elem
    return self
end

function XmlBuilder:attr(name,value)
    assert(self.element~=nil,"Element must be specified before attributes.")
    assert(name~=nil,"Attribute name must be supplied.")
    local attrib = self.element.attrib
    if attrib == nil then
        attrib = {}
        self.element.attrib = attrib
    end
    table.insert(attrib,{name=name, value=value or ""})
    return self
end

function XmlBuilder:push()
    local elem = self.element
    assert(elem~=nil,"Element must be specified before push.")
    assert(elem.value == nil,"Element cannot have value and contain children.")
    elem.hasChildren = true
    -- must not fully commit an element otherwise elements won't contain children
    commitElement(self.document,elem,true)
    self.element = nil
    table.insert(self.stack,elem)
    return self
end

function XmlBuilder:pop()
    local elem = self.stack[#self.stack]
    assert(elem ~= nil, "Cannot pop stack before push")
    table.remove(self.stack)
    if self.element then
        self.element = commitElement(self.document,self.element)
    end
    self.element = elem
    return self
end

function XmlBuilder:toString()
    while #self.stack > 0 do
        self:pop()
    end
    if self.element then
        self.element = commitElement(self.document,self.element)
    end
    return table.concat(self.document)
end
