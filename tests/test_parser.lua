package.path = "./?.lua;./?/init.lua;" .. package.path

local parser = require("parser")

local function assert_eq(actual, expected, message)
    if actual ~= expected then
        error((message or "assertion failed") .. "\nexpected: " .. expected .. "\nactual:   " .. actual)
    end
end

local function assert_contains(haystack, needle, message)
    if not haystack:find(needle, 1, true) then
        error((message or "assertion failed") .. "\nexpected to find: " .. needle .. "\nactual:\n" .. haystack)
    end
end

assert_eq(parser.parse("# Hello"), "<h1>Hello</h1>")
assert_eq(parser.inline("**bold** and *italic*"), "<strong>bold</strong> and <em>italic</em>")
assert_eq(parser.inline("[text](http://example.com)"), '<a href="http://example.com">text</a>')
assert_eq(parser.inline("`a < b`"), "<code style='white-space: pre;'>a &lt; b</code>")
assert_eq(parser.inline("\\*literal\\*"), "*literal*")

local nested = parser.parse("> > nested")
assert_contains(nested, "<blockquote>\n<blockquote>\nnested")

local task_markdown = "- [ ] todo\n- [x] done\n- [X] done2"
local task_html = parser.parse(task_markdown)
assert_contains(task_html, "<input type='checkbox' disabled> todo")
assert_contains(task_html, "<input type='checkbox' checked disabled> done")
assert_contains(task_html, "<input type='checkbox' checked disabled> done2")

print("all parser tests passed")
