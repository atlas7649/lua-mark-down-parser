local parser = {}

function parser.inline(text)
    local res = text

    -- Handle escaping: \* -> *, \` -> `, etc.
    -- We temporarily replace escaped characters with placeholders
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
    while res:match("`(.-)`") do
        res = res:gsub("`(.-)`", "<code>%1</code>")
    end

    -- Images: ![alt](url)
    while res:match("!%[(.-)%]%((.-)%") do
        res = res:gsub("!%[(.-)%]%((.-)%")", '<img src="%2" alt="%1">')
    end

    -- Hyperlinks: [text](url)
    while res:match("%[(.-)%]%((.-)%") do
        res = res:gsub("%[(.-)%]%((.-)%")", '<a href="%2">%1</a>')
    end

    -- Strike-through: ~~text~~
    while res:match("%~%~([^%n~]+)%~%~") do
        res = res:gsub("%~%~([^%n~]+)%~%~", "<del>%1</del>")
    end

    -- Bold: **text**
    while res:match("%*%*([^*%n]+)%*%*") do
        res = res:gsub("%*%*([^*%n]+)%*%*", "<strong>%1</strong>")
    end

    -- Italic: *text*
    while res:match("%*([^*%n]+)%*") do
        res = res:gsub("%*([^*%n]+)%*", "<em>%1</em>")
    end

    -- Restore escaped characters
    for idx, char in ipairs(escapes) do
        res = res:gsub("__ESC" .. (idx-1) .. "__", char)
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
        elseif trimmed:match("^---$") then
            if in_list then
                table.insert(html, "</" .. list_type .. ">")
                in_list = false
                list_type = nil
            end
            if in_quote then
                table.insert(html, "</blockquote>")
                in_quote = false
            end
            table.insert(html, "<hr />")
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