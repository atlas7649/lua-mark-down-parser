local parser = require("parser")

local md = "# Hello World\n\nThis is a test of the parser with **bold** and *italic* text.\n\n- Item 1 with **bold**\n- Item 2 with *italic*\n\n## Subheader\nAnother paragraph."

local html = parser.parse(md)
print("Markdown:\n" .. md)
print("\nHTML:\n" .. html)

-- Basic verification
local success = true
if not html:find("<h1>Hello World</h1>") then success = false end
if not html:find("<ul>") then success = false end
if not html:find("<strong>bold</strong>") then success = false end
if not html:find("<em>italic</em>") then success = false end

if success then
    print("\nTest Passed!")
else
    print("\nTest Failed!")
end