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

assert_eq(parser.inline("`*not bold*`"), "<code style='white-space: pre;'>*not bold*</code>")
assert_eq(parser.inline("`~~no strike~~`"), "<code style='white-space: pre;'>~~no strike~~</code>")

local nested = parser.parse("> > nested")
assert_contains(nested, "<blockquote>\n<blockquote>\nnested")

local task_markdown = "- [ ] todo\n- [x] done\n- [X] done2"
local task_html = parser.parse(task_markdown)
assert_contains(task_html, "<input type='checkbox' disabled> todo")
assert_contains(task_html, "<input type='checkbox' checked disabled> done")
assert_contains(task_html, "<input type='checkbox' checked disabled> done2")

local fenced = parser.parse("```\nhello\nworld\n```")
assert_contains(fenced, "<pre><code class=\"\">")
assert_contains(fenced, "hello")
assert_contains(fenced, "world")

local indented = parser.parse("    hello\n    world")
assert_contains(indented, "<pre><code>")
assert_contains(indented, "hello")
assert_contains(indented, "world")

assert_eq(parser.parse("---"), "<hr />")
assert_eq(parser.parse("***"), "<hr />")
assert_eq(parser.parse("___"), "<hr />")

local table_md = "| a | b |\n|---|---|\n| 1 | 2 |"
local table_html = parser.parse(table_md)
assert_contains(table_html, "<table>")
assert_contains(table_html, "<th>a</th>")
assert_contains(table_html, "<td>1</td>")

local aligned_table = parser.parse("| a | b |\n|:---:|---:|\n| 1 | 2 |")
assert_contains(aligned_table, "<th>a</th>")
assert_contains(aligned_table, "<td>2</td>")

local quote_then_list = parser.parse("> quote\n- item")
assert_contains(quote_then_list, "</blockquote>")

local indented_fence = parser.parse("  ```lua\nvalue\n  ```")
assert_contains(indented_fence, "<pre><code class=\"lua\">")
assert_contains(indented_fence, "value")

local spaced_header = parser.parse("  ## Hello")
assert_contains(spaced_header, "<h2>Hello</h2>")

assert_eq(parser.inline("<b>text</b>"), "&lt;b&gt;text&lt;/b&gt;")
assert_contains(parser.parse("Hello <b>world</b>"), "&lt;b&gt;world&lt;/b&gt;")
assert_eq(parser.parse("  ## Hello  "), "<h2>Hello</h2>")
assert_eq(parser.parse("  Hello  \n  ====  "), "<h1>Hello</h1>")

local separated_lists = parser.parse("- a\n\n- b")
assert_contains(separated_lists, "</ul>\n<ul>")

assert_eq(parser.inline("~~text~~"), "<del>text</del>")
assert_eq(parser.inline("~~a~~ and ~~b~~"), "<del>a</del> and <del>b</del>")
assert_eq(parser.inline("~~a~b~~"), "<del>a~b</del>")
assert_eq(parser.inline("~~*text*~~"), "<del><em>text</em></del>")
assert_eq(parser.parse("## Hello ##"), "<h2>Hello</h2>")
assert_eq(parser.parse("# C#"), "<h1>C#</h1>")

print("all parser tests passed")
