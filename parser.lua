local parser = {}

function parser.inline(text)
    local res = text

    -- Inline Code: `code`
    while res:match("%%`(.-)%%`") do
        res = res:gsub("%%`(.-)%%`", "<code>%1</code>")
    end

    -- Hyperlinks: [text](url)
    -- Lua patterns don't support non-greedy, so we look for the closing bracket/paren
    while res:match("%[(.-)%]%((.-)%)") do
        res = res:gsub("%[(.-)%]%((.-)%)", '<a href="%2">%1</a>')
    end

    -- Bold: **text**
    -- Use a pattern that avoids matching internal stars to prevent runaway recursion
    while res:match("%%*%*([^*%n]+)%%*%*") do
        res = res:gsub("%%*%*([^*%n]+)%%*%*", "<strong>%1</strong>")
    end

    -- Italic: *text*
    while res:match("%%*([^*%n]+)%%*") do
        res = res:gsub("%%*([^*%n]+)%%*", "<em>%1</em>")
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
    local in_quote = false

    for i, line in ipairs(lines) do
        local trimmed = line:match("^%s*(.+)%s*$") or ""
        
        if trimmed:match("^-%s*(.+)") then
            if in_quote then
                table.insert(html, "</blockquote>")
                in_quote = false
            end
            if not in_list then
                table.insert(html, "<ul>")
                in_list = true
            end
            local content = trimmed:match("^-%s*(.+)")
            table.insert(html, "  <li>" .. parser.inline(content) .. "</li>")
            goto continue
        elseif trimmed:match("^>%s*(.+)") then
            if in_list then
                table.insert(html, "</ul>")
                in_list = false
            end
            if not in_quote then
                table.insert(html, "<blockquote>")
                in_quote = true
            end
            local content = trimmed:match("^>%s*(.+)")
            table.insert(html, "  <p>" .. parser.inline(content) .. "</p>")
            goto continue
        else
            if in_list then
                table.insert(html, "</ul>")
                in_list = false
            end
            if in_quote then
                table.insert(html, "</blockquote>")
                in_quote = false
            end
        end

        local h_match = trimmed:match("^(#+)(.+)")
        if h_match then
            local level_str, content = trimmed:match("^(#+)(.+)")
            local level = #level_str
            table.insert(html, string.format("<h%d>%s</h%d>", level, parser.inline(content:gsub("^%s*", "")), level))
            goto continue
        end

        if trimmed ~= "" then
            table.insert(html, "<p>" .. parser.inline(trimmed) .. "</p>")
        end

        ::continue::
    end

    if in_list then
        table.insert(html, "</ul>")
    end
    if in_quote then
        table.insert(html, "</blockquote>")
    end

    return table.concat(html, "\n")
end

return parser