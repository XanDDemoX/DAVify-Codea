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
