# Lua Markdown Parser

A simple, lightweight Markdown to HTML converter written in pure Lua.

## Features
- Headers (#)
- Bold (**)
- Italic (*)
- Unordered Lists (-)
- Ordered Lists (1.)
- Task Lists (- [ ] / - [x])
- Blockquotes (>)
- Nested Blockquotes
- Paragraphs
- Images (![alt](url))
- Hyperlinks ([text](url))
- Inline Code (`code`)
- Fenced and Indented Code Blocks
- Tables
- Horizontal Rules (---, ***, ___)
- Strikethrough (~~text~~)

## Usage

```lua
local parser = require("parser")

print(parser.parse("# Hello World"))
print(parser.inline("**bold** and *italic*"))
```

## Running Tests

```sh
lua tests/test_parser.lua
```
