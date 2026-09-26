local parser = {}

function parser.inline(text)
    local res = text

    -- Handle escaping: \* -> *, \` -> `, etc.
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
    res = res:gsub("`(.-)`", "<code>%1</code>")

    -- Images: ![alt](url)
    res = res:gsub("!%[(.-)%]%((.-)%")", '<img src="%2" alt="%1">')

    -- Hyperlinks: [text](url)
    res = res:gsub("%[(.-)%]%((.-)%")", '<a href="%2">%1</a>')

    -- Strike-through: ~~text~~
    res = res:gsub("%~%~([^%n~]+)%~%~", "<del>%1</del>")

    -- Bold-Italic: ***text***
    res = res:gsub("%*%*%*([^*%n]+)%*%*%*", "<strong><em>%1</em></strong>")

    -- Bold: **text**
    res = res:gsub("%*%*([^*%n]+)%*%*", "<strong>%1</strong>")

    -- Italic: *text*
    res = res:gsub("%*([^*%n]+)%*", "<em>%1</em>")

    -- Restore escaped characters
    for idx, char in ipairs(escapes) do
        res = res:gsub("__ESC" .. idx .. "__", char)
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
        -- Fenced Code Block
        if line:match("^```") then
            if block_type == "fenced" then
                table.insert(html, "</code></pre>")
                block_type = nil
            else
                close_blocks()
                local lang = line:match("^```(%S*)") or ""
                table.insert(html, string.format("<pre><code class=\"%s\">", lang))
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
            table.insert(html, content)
            goto continue
        elseif block_type == "indented" and not (line:match("^    ") or line:match("^\t")) and line ~= "" then
            table.insert(html, "</code></pre>")
            block_type = nil
        end

        if block_type == "fenced" then
            table.insert(html, line)
            goto continue
        end

        -- Horizontal Rule
        if line:match("^---$") then
            close_blocks()
            table.insert(html, "<hr />")
            goto continue
        end

        -- Headers
        local hashes = line:match("^(#+)")
        if hashes then
            close_blocks()
            local level = #hashes
            local text = line:sub(level + 2)
            table.insert(html, string.format("<h%d>%s</h%d>", level, parser.inline(text), level))
            goto continue
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
            table.insert(html, "<p>" .. parser.inline(line) .. "</p>")
        end

        ::continue::
    end

    close_blocks()
    return table.concat(html, "\n")
end

return parser