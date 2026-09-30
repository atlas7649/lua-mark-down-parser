local parser = {}

local function html_escape(text)
    local replacements = {
        ["&"] = "&amp;",
        ["<"] = "&lt;",
        [">"] = "&gt;",
        ["\""] = "&quot;",
        ["'"] = "&#39;",
    }
    return (text:gsub("[%&<>\"']", replacements))
end

function parser.inline(text)
    if not text then return "" end
    local res = text

    -- Handle escaping: \* -> *, \` -> `, \~ -> ~, etc.
    local escapes = {}
    local i = 1
    while i <= #res do
        if res:sub(i, i) == "\" then
            local char = res:sub(i+1, i+1)
            if char ~= "" then
                local placeholder = "__ESC" .. #escapes .. "__"
                escapes[#escapes + 1] = char
                res = res:sub(1, i-1) .. placeholder .. res:sub(i+2)
                i = i + #placeholder
                goto continue
            end
        end
        i = i + 1
        ::continue::
    end

    -- Inline Code: `code`
    res = res:gsub("`(.-)`", function(code) return "<code style='white-space: pre;'>" .. html_escape(code) .. "</code>" end)

    -- Images: ![alt](url)
    res = res:gsub("!%[(.-)%]%((.-)%)", function(alt, url) return string.format('<img src="%s" alt="%s">', html_escape(url), html_escape(alt)) end)

    -- Hyperlinks: [text](url)
    res = res:gsub("%[(.-)%]%((.-)%)", function(text, url) return string.format('<a href="%s">%s</a>', html_escape(url), parser.inline(text)) end)

    -- Strike-through: ~~text~~
    res = res:gsub("%~%~([^%n~]+)%~%~", "<del>%1</del>")

    -- Bold-Italic: ***text***
    res = res:gsub("%*%*%*([^*%n]+)%*%*%*", "<strong><em>%1</em></strong>")

    -- Bold: **text**
    res = res:gsub("%*%*([^*%n]+)%*%*", "<strong>%1</strong>")

    -- Italic: *text*
    res = res:gsub("%*([^*%n]+)%*", "<em>%1</em>")

    -- Restore escaped characters
    for idx = #escapes, 1, -1 do
        local placeholder = "__ESC" .. idx .. "__"
        res = res:gsub(placeholder, escapes[idx])
    end

    return res
end

function parser.parse(text)
    local lines = {}
    for line in text:gmatch("[^\n]*") do
        table.insert(lines, line)
    end

    local html = {}
    local in_list = false
    local list_type = nil -- 'ul' or 'ol'
    local in_quote = false
    local block_type = nil -- 'fenced' or 'indented'
    local skip_next = false

    local function close_blocks()
        if block_type then
            table.insert(html, "</code></pre>")
            block_type = nil
        end
        if in_list then
            table.insert(html, "</" .. list_type .. ">")
            in_list = false
            list_type = nil
        end
        if in_quote then
            table.insert(html, "</blockquote>")
            in_quote = false
        end
    end

    for i, line in ipairs(lines) do
        if skip_next then
            skip_next = false
            goto continue
        end

        -- Fenced Code Block
        if line:match("^```") then
            if block_type == "fenced" then
                table.insert(html, "</code></pre>")
                block_type = nil
            else
                close_blocks()
                local lang = line:match("^```(%S*)") or ""
                table.insert(html, string.format("<pre><code class=\"%s\">", html_escape(lang)))
                block_type = "fenced"
            end
            goto continue
        end

        -- Indented Code Block
        if block_type ~= "fenced" and (line:match("^    ") or line:match("^\t")) then
            if block_type ~= "indented" then
                close_blocks()
                table.insert(html, "<pre><code>")
                block_type = "indented"
            end
            local content = line:match("^    (.-)$") or line:match("^\t(.-)$") or ""
            table.insert(html, html_escape(content))
            goto continue
        elseif block_type == "indented" and not (line:match("^    ") or line:match("^\t")) and line ~= "" then
            table.insert(html, "</code></pre>")
            block_type = nil
        end

        if block_type == "fenced" then
            table.insert(html, html_escape(line))
            goto continue
        end

        -- Horizontal Rule
        if line:match("^---$") then
            close_blocks()
            table.insert(html, "<hr />")
            goto continue
        end

        -- Headers (ATX style)
        local hashes = line:match("^(#+)")
        if hashes then
            close_blocks()
            local level = #hashes
            local text = line:sub(level + 2)
            table.insert(html, string.format("<h%d>%s</h%d>", level, parser.inline(text), level))
            goto continue
        end

        -- Setext-style Headers (Underlined)
        if i < #lines then
            local next_line = lines[i+1]
            if next_line and next_line:match("^={3,}$") then
                close_blocks()
                table.insert(html, string.format("<h1>%s</h1>", parser.inline(line)))
                skip_next = true
                goto continue
            elseif next_line and next_line:match("^-{3,}$") then
                close_blocks()
                table.insert(html, string.format("<h2>%s</h2>", parser.inline(line)))
                skip_next = true
                goto continue
            end
        end

        -- Blockquotes
        if line:match("^>") then
            if not in_quote then
                close_blocks()
                table.insert(html, "<blockquote>")
                in_quote = true
            end
            local content = line:sub(2):gsub("^%s", "")
            table.insert(html, parser.inline(content))
            goto continue
        elseif in_quote and line ~= "" then
            table.insert(html, "</blockquote>")
            in_quote = false
        end

        -- Lists
        local ul_match = line:match("^%s*-%s*(.-)$")
        local ol_match = line:match("^%s*%d+%.%s*(.-)$")
        if ul_match or ol_match then
            local current_type = ul_match and "ul" or "ol"
            local content = ul_match or ol_match
            if not in_list or list_type ~= current_type then
                if in_list then table.insert(html, "</" .. list_type .. ">") end
                table.insert(html, "<" .. current_type .. ">")
                in_list = true
                list_type = current_type
            end
            table.insert(html, "<li>" .. parser.inline(content) .. "</li>")
            goto continue
        elseif in_list and line ~= "" then
            table.insert(html, "</" .. list_type .. ">")
            in_list = false
            list_type = nil
        end

        -- Paragraphs
        if line ~= "" then
            if not in_quote then
                close_blocks()
            end
            table.insert(html, "<p>" .. parser.inline(line) .. "</p>")
        end

        ::continue::
    end

    close_blocks()
    return table.concat(html, "\n")
end

return parser