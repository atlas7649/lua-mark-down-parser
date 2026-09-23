local parser = require("parser")

local md = "# Hello World\n\nThis is a test of the parser with **bold**, *italic*, and `inline code`. You can also use [a link](https://lua.org).\n\n- Item 1 with **bold**\n- Item 2 with `code` in list\n\n1. First ordered item\n2. Second ordered item\n\n> This is a blockquote\n> With multiple lines\n\n## Subheader\nAnother paragraph."

local html = parser.parse(md)
print("Markdown:\n" .. md)
print("\nHTML:\n" .. html)

-- Basic verification
local success = true
if not html:find("<h1>Hello World</h1>") then success = false end
if not html:find("<ul>") then success = false end
if not html:find("<ol>") then success = false end
if not html:find("<strong>bold</strong>") then success = false end
if not html:find("<em>italic</em>") then success = false end
if not html:find("<code>inline code</code>") then success = false end
if not html:find('<a href="https://lua.org">a link</a>') then success = false end
if not html:find("<blockquote>") then success = false end
if not html:find("</blockquote>") then success = false end

if success then
    print("\nTest Passed!")
else
    print("\nTest Failed!")
end