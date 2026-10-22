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

local function is_table_separator(row_text)
    local row = row_text:match("^%s*(.-)%s*$")
    if not row or not row:match("^|") then
        return false
    end

    local inner = row:gsub("^|", "")
    inner = inner:gsub("|%s*$", "")
    if inner == "" then
        return false
    end

    local pos = 1
    while pos <= #inner do
        local pipe = inner:find("|", pos, true)
        local cell = pipe and inner:sub(pos, pipe - 1) or inner:sub(pos)
        local trimmed = cell:match("^%s*(.-)%s*$")
        if not trimmed or not trimmed:match("^:?-+:?$") then
            return false
        end
        if not pipe then
            break
        end
        pos = pipe + 1
    end

    return true
end

local function inline_render(text)
    if not text or text == "" then return "" end
    local res = text

    -- Handle escaping: \* -> *, \` -> `, \~ -> ~, etc.
    local escapes = {}
    local i = 1
    while i <= #res do
        if res:sub(i, i) == "\\" then
            local char = res:sub(i+1, i+1)
            if char ~= "" then
                escapes[#escapes + 1] = char
                local placeholder = "__ESC" .. #escapes .. "__"
                res = res:sub(1, i-1) .. placeholder .. res:sub(i+2)
                i = i + #placeholder
                goto continue
            end
        end
        i = i + 1
        ::continue::
    end

    -- Inline Code: `code`
    res = res:gsub("`([^`]*)`", function(code) return "<code style='white-space: pre;'>" .. code .. "</code>" end)

    -- Images: ![alt](url)
    res = res:gsub("!%[(.-)%]%((.-)%)", function(alt, url) return string.format('<img src="%s" alt="%s">', url, alt) end)

    -- Hyperlinks: [text](url)
    res = res:gsub("%[(.-)%]%((.-)%)", function(text, url) return string.format('<a href="%s">%s</a>', url, inline_render(text)) end)

    -- Strike-through: ~~text~~
    res = res:gsub("%~%~([^%n~]+)%~%~", function(content) return "<del>" .. inline_render(content) .. "</del>" end)

    -- Bold-Italic: ***text***
    res = res:gsub("%*%*%*([^*%n]+)%*%*%*", "<strong><em>%1</em></strong>")

    -- Bold: **text**
    res = res:gsub("%*%*([^*%n]+)%*%*", "<strong>%1</strong>")

    -- Italic: *text*
    res = res:gsub("%*([^*%n]+)%*", "<em>%1</em>")

    -- Restore escaped characters
    for idx = #escapes, 1, -1 do
        local placeholder = "__ESC" .. idx .. "__"
        res = res:gsub(placeholder, function() return escapes[idx] end)
    end

    return res
end

function parser.inline(text)
    if not text or text == "" then return "" end
    return inline_render(html_escape(text))
end

function parser.parse(text)
    text = text:gsub("\r\n", "\n")
    text = text:gsub("\r", "\n")

    local lines = {}
    for line in text:gmatch("[^\n]*") do
        table.insert(lines, line)
    end

    local html = {}
    local in_list = false
    local list_type = nil -- 'ul' or 'ol'
    local quote_depth = 0
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
        while quote_depth > 0 do
            table.insert(html, "</blockquote>")
            quote_depth = quote_depth - 1
        end
    end

    local function close_code_and_list()
        if block_type then
            table.insert(html, "</code></pre>")
            block_type = nil
        end
        if in_list then
            table.insert(html, "</" .. list_type .. ">")
            in_list = false
            list_type = nil
        end
    end

    local i = 1
    while i <= #lines do
        local line = lines[i]

        -- Fenced Code Block
        local fence_leading = line:match("^(%s*)```")
        if fence_leading and #fence_leading <= 3 then
            if block_type == "fenced" then
                table.insert(html, "</code></pre>")
                block_type = nil
            else
                close_blocks()
                local lang = line:match("^%s*```%s*(%S*)") or ""
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
        elseif block_type == "indented" and not (line:match("^    ") or line:match("^\t")) and line:match("%S") then
            table.insert(html, "</code></pre>")
            block_type = nil
        end

        if block_type == "indented" and not line:match("%S") then
            table.insert(html, "")
            goto continue
        end

        if block_type == "fenced" then
            table.insert(html, html_escape(line))
            goto continue
        end

        if not line:match("%S") then
            close_blocks()
            goto continue
        end

        -- Horizontal Rule / Thematic Break
        local hr_stripped = line:gsub("%s", "")
        if #hr_stripped >= 3 and (hr_stripped:match("^%-+$") or hr_stripped:match("^%*+$") or hr_stripped:match("^_+$")) then
            close_blocks()
            table.insert(html, "<hr />")
            goto continue
        end

        -- Headers (ATX style)
        local leading, hashes = line:match("^(%s*)(#+)")
        if leading and #leading <= 3 and hashes and #hashes <= 6 then
            local rest = line:sub(#leading + #hashes + 1)
            if rest == "" or rest:match("^%s") then
                close_blocks()
                local text = rest:gsub("^%s+", ""):gsub("%s+$", "")
                table.insert(html, string.format("<h%d>%s</h%d>", #hashes, parser.inline(text), #hashes))
                goto continue
            end
        end

        -- Setext-style Headers (Underlined)
        if line:match("%S") and i < #lines then
            local next_line = lines[i+1]
            if next_line and next_line:match("^%s*=+%s*$") then
                close_blocks()
                table.insert(html, string.format("<h1>%s</h1>", parser.inline(line:match("^%s*(.-)%s*$"))))
                i = i + 1
                goto continue
            elseif next_line and next_line:match("^%s*%-+%s*$") then
                close_blocks()
                table.insert(html, string.format("<h2>%s</h2>", parser.inline(line:match("^%s*(.-)%s*$"))))
                i = i + 1
                goto continue
            end
        end

        -- Tables
        if line:match("^%s*|") then
            close_blocks()
            local table_lines = {line}
            local j = i + 1
            while j <= #lines and lines[j]:match("^%s*|") do
                table.insert(table_lines, lines[j])
                j = j + 1
            end

            if #table_lines >= 2 then
                table.insert(html, "<table>")
                for row_idx, row_text in ipairs(table_lines) do
                    -- Skip separator row (e.g., |---|---| or | :---: | :---: |)
                    if row_idx == 2 and is_table_separator(row_text) then
                        goto skip_row
                    end

                    local tag = (row_idx == 1) and "th" or "td"
                    table.insert(html, "<tr>")

                    -- Remove leading/trailing whitespace, then leading and trailing pipes
                    local row = row_text:match("^%s*(.-)%s*$")
                    row = row:gsub("^|", ""):gsub("|$", "")

                    -- Split by pipe manually to handle empty cells
                    local cells = {}
                    local current = ""
                    for char in row:gmatch(".") do
                        if char == "|" then
                            table.insert(cells, current)
                            current = ""
                        else
                            current = current .. char
                        end
                    end
                    table.insert(cells, current)

                    for _, cell in ipairs(cells) do
                        table.insert(html, string.format("<%s>%s</%s>", tag, parser.inline(cell:gsub("^%s*(.-)%s*$", "%1")), tag))
                    end

                    table.insert(html, "</tr>")
                    ::skip_row::
                end
                table.insert(html, "</table>")
                i = j - 1
                goto continue
            end
        end

        -- Blockquotes
        local prefix_end = 1
        while prefix_end <= #line and (line:sub(prefix_end, prefix_end) == " " or line:sub(prefix_end, prefix_end) == ">") do
            prefix_end = prefix_end + 1
        end
        local quote_prefix = line:sub(1, prefix_end - 1)
        local current_depth = select(2, quote_prefix:gsub(">", ""))
        if current_depth > 0 then
            if in_list or block_type then
                close_code_and_list()
            end
            while quote_depth > current_depth do
                table.insert(html, "</blockquote>")
                quote_depth = quote_depth - 1
            end
            while quote_depth < current_depth do
                table.insert(html, "<blockquote>")
                quote_depth = quote_depth + 1
            end
            local content = line:sub(prefix_end):match("^%s*(.-)%s*$")
            table.insert(html, parser.inline(content))
            goto continue
        elseif quote_depth > 0 then
            close_blocks()
        end

        -- Lists
        local ul_match = line:match("^%s*-%s*(.-)$")
        local ol_match = line:match("^%s*%d+%.%s*(.-)$")
        if ul_match or ol_match then
            local current_type = ul_match and "ul" or "ol"
            local content = ul_match or ol_match
            content = content:gsub("^%s+", ""):gsub("%s+$", "")

            -- Close any open blockquote before starting a list.
            while quote_depth > 0 do
                table.insert(html, "</blockquote>")
                quote_depth = quote_depth - 1
            end

            -- Handle Task Lists for unordered lists
            if current_type == "ul" then
                content = content:gsub("^%[%s*[xX]%s*%]%s*(.-)%s*$", "<input type='checkbox' checked disabled> %1")
                content = content:gsub("^%[%s* %s*%]%s*(.-)%s*$", "<input type='checkbox' disabled> %1")
            end

            if not in_list or list_type ~= current_type then
                if in_list then table.insert(html, "</" .. list_type .. ">") end
                table.insert(html, "<" .. current_type .. ">")
                in_list = true
                list_type = current_type
            end
            table.insert(html, "<li>" .. parser.inline(content) .. "</li>")
            goto continue
        elseif in_list and line:match("%S") then
            table.insert(html, "</" .. list_type .. ">")
            in_list = false
            list_type = nil
        end

        -- Paragraphs
        if line:match("%S") then
            if not (quote_depth > 0) then
                close_blocks()
            end
            table.insert(html, "<p>" .. parser.inline(line:match("^%s*(.-)%s*$")) .. "</p>")
        end

        ::continue::
        i = i + 1
    end

    close_blocks()
    return table.concat(html, "\n")
end

return parser
