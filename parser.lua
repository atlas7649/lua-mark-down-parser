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
    local list_type = nil -- 'ul' or 'ol'
    local in_quote = false

    for i, line in ipairs(lines) do
        local trimmed = line:match("^%s*(.+)%s*$") or ""
        
        local is_ul = trimmed:match("^-%s*(.+)")
        local is_ol = trimmed:match("^%d+%.%s*(.+)")

        if is_ul or is_ol then
            local current_type = is_ul and "ul" or "ol"
            local content = is_ul and trimmed:match("^-%s*(.+)") or trimmed:match("^%d+%.%s*(.+)")

            if in_quote then
                table.insert(html, "</blockquote>")
                in_quote = false
            end

            if not in_list or list_type ~= current_type then
                if in_list then
                    table.insert(html, "</" .. list_type .. ">")
                end
                table.insert(html, "<" .. current_type .. ">")
                in_list = true
                list_type = current_type
            end

            table.insert(html, "  <li>" .. parser.inline(content) .. "</li>")
            goto continue
        elseif trimmed:match("^>%s*(.+)") then
            if in_list then
                table.insert(html, "</" .. list_type .. ">")
                in_list = false
                list_type = nil
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
                table.insert(html, "</" .. list_type .. ">")
                in_list = false
                list_type = nil
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
        table.insert(html, "</" .. list_type .. ">")
    end
    if in_quote then
        table.insert(html, "</blockquote>")
    end

    return table.concat(html, "\n")
end

return parser