local parser = {}

function parser.inline(text)
    local res = text
    -- Bold: **text**
    res = res:gsub("%%(%*%*%s*([^*%s][^*]*[^*%s]%s*%)%*%%)", "<strong>%1</strong>")
    -- Using a more reliable approach for Lua's pattern matching
    -- Since Lua patterns don't support non-greedy matches or lookaheads,
    -- we handle basic markers. 
    
    -- Corrected Bold: **text**
    res = res:gsub("%%(%*%(%*%s*([^*]*)%*%)%*%%", "<strong>%2</strong>")
    
    -- Simple Lua-friendly Bold and Italic
    -- Bold
    while res:match("%*%*([^*%n]+)%*%*") do
        res = res:gsub("%*%*([^*%n]+)%*%*", "<strong>%1</strong>")
    end
    -- Italic
    while res:match("%*([^*%n]+)%*") do
        res = res:gsub("%*([^*%n]+)%*", "<em>%1</em>")
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

    for i, line in ipairs(lines) do
        local trimmed = line:match("^%s*(.+)%s*$") or ""
        
        if trimmed:match("^-%s*(.+)") then
            if not in_list then
                table.insert(html, "<ul>")
                in_list = true
            end
            local content = trimmed:match("^-%s*(.+)")
            table.insert(html, "  <li>" .. parser.inline(content) .. "</li>")
            goto continue
        else
            if in_list then
                table.insert(html, "</ul>")
                in_list = false
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

    return table.concat(html, "\n")
end

return parser