local parser = require("parser")

local md = "# Hello World\n\nThis is a test of the parser.\n\n- Item 1\n- Item 2\n\n## Subheader\nAnother paragraph."

local html = parser.parse(md)
print("Markdown:\n" .. md)
print("\nHTML:\n" .. html)

-- Basic verification
if html:find("<h1>Hello World</h1>") and html:find("<ul>") then
    print("\nTest Passed!")
else
    print("\nTest Failed!")
end