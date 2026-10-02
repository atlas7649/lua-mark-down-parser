local parser = require("parser")

local md = "# Hello World\n\nThis is a test of the parser with **bold**, *italic*, ~~strike~~, and `inline code`. You can also use [a link](https://lua.org) and an image ![Lua Logo](https://lua.org/logo.png).\n\n---\n
- Item 1 with **bold**\n- Item 2 with `code` in list\n\n1. First ordered item\n2. Second ordered item\n\n---\n
> This is a blockquote\n> With multiple lines\n\n## Subheader\nAnother paragraph.\n\n### Escaping Test\nThis is a literal asterisk: \* and literal backtick: \` and literal tilde: \~.\n\n#### Code Block Test\n    local x = 10\n    print(x)\n\n##### Fenced Code Block\n```lua\nprint(\"Hello Fenced\")\n```\n\nBack to normal text.\n\nSetext H1\n=======

Setext H2
-------

| Header 1 | Header 2 |
|----------|----------|
| Cell 1   | Cell 2   |
| Cell 3   | Cell 4   |"

local html = parser.parse(md)
print("Markdown:\n" .. md)
print("\nHTML:\n" .. html)

local success = true
if not html:find("<h1>Hello World</h1>") then success = false end
if not html:find("<ul>") then success = false end
if not html:find("<ol>") then success = false end
if not html:find("<strong>bold</strong>") then success = false end
if not html:find("<em>italic</em>") then success = false end
if not html:find("<del>strike</del>") then success = false end
if not html:find("<code>inline code</code>") then success = false end
if not html:find('<a href="https://lua.org">a link</a>') then success = false end
if not html:find('<img src="https://lua.org/logo.png" alt="Lua Logo">') then success = false end
if not html:find("<blockquote>") then success = false end
if not html:find("</blockquote>") then success = false end
if not html:find("<hr />") then success = false end

-- Escaping verification
if html:find("<em>\*</em>") then success = false end
if not html:find("literal asterisk: \*") then success = false end
if not html:find("literal backtick: `") then success = false end
if not html:find("literal tilde: ~") then success = false end

-- Code block verification
if not html:find("<pre><code>") then success = false end
if not html:find("local x = 10") then success = false end
if not html:find("</code></pre>") then success = false end

-- Fenced code block verification
if not html:find('<pre><code class="lua">') then success = false end
if not html:find("print(\"Hello Fenced\")") then success = false end

-- Setext verification
if not html:find("<h1>Setext H1</h1>") then success = false end
if not html:find("<h2>Setext H2</h2>") then success = false end

-- Table verification
if not html:find("<table>") then success = false end
if not html:find("<th>Header 1</th>") then success = false end
if not html:find("<td>Cell 4</td>") then success = false end
if not html:find("</table>") then success = false end

-- HTML Entity Test
local html_entity_md = "Check <this> & that"
local html_entity_res = parser.parse(html_entity_md)
if not html_entity_res:find("Check &lt;this&gt; &amp; that") then
    print("HTML Entity Test Failed!")
    success = false
end

-- Task List Test
local task_md = "- [x] Done\n- [ ] Not Done"
local task_res = parser.parse(task_md)
if not task_res:find("checked disabled") or not task_res:find("disabled") then
    print("Task List Test Failed!")
    success = false
end

-- Link with inline content test
local inline_link_md = "Check [**this bold link**](https://lua.org)"
local inline_link_res = parser.parse(inline_link_md)
if not inline_link_res:find('<a href="https://lua.org"><strong>this bold link</strong></a>') then
    print("Inline Link Test Failed!")
    success = false
end

if success then
    print("\nTest Passed!")
else
    print("\nTest Failed!")
end