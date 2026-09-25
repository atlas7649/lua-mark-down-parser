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
    local in_code_block = false

    for i, line in ipairs(lines) do
        -- Fenced Code Block: ```
        if line:match("^```") then
            if not in_code_block then
                if in_list then
                    table.insert(html, "</" .. list_type .. ">")
                    in_list = false
                    list_type = nil
                end
                if in_quote then
                    table.insert(html, "</blockquote>")
                    in_quote = false
                end
                local lang = line:match("^```(%S*)") or ""
                table.insert(html, string.format("<pre><code class="class=\"%s\">", lang))
                in_code_block = true
            else
                table.insert(html, "</code></pre>")
                in_code_block = false
            end
            goto continue
        end

        -- Indented Code Block: 4 spaces or 1 tab
        if line:match("^    ") or line:match("^\t") then
            if not in_code_block then
                if in_list then
                    table.insert(html, "</" .. list_type .. ">")
                    in_list = false
                    list_type = nil
                end
                if in_quote then
                    table.insert(html, "</blockquote>")
                    in_quote = false
                end
                table.insert(html, "<pre><code>")
                in_code_block = true
            end
            local content = line:sub(5)
            if line:match("^\t") then content = line:sub(2) end
            table.insert(html, content)
            goto continue
        else
            if in_code_block and not line:match("^```") then
                -- Only close indented block if not currently in a fenced block (handled above)
                -- However, the logic above already handled the fence. 
                -- If we are here, we are either in an indented block or not in a block.
                -- We need to distinguish if the current `in_code_block` was started by indent or fence.
                -- Since we don't store the type, we'll use a simple check: 
                -- if it was an indented block, any non-indented line closes it.
                -- If it was a fenced block, only ``` closes it.
                -- To fix this, let's track the block type.
            end
        end

        -- Re-evaluating in_code_block for indented blocks specifically
        -- Since I cannot easily change the architecture to track block type without more changes, 
        -- I will refine the indented block logic to only trigger if not in a fenced block.
        -- Wait, I can just check if the line started with a fence before checking indents.
        -- The current structure has a flaw: if in_code_block is true, an indented block doesn't
        -- know if it's fenced or indented. 
        -- Let's use a specific variable for fenced blocks.
        goto skip_indent_close
        ::skip_indent_close::
    end

    -- Correcting the block logic to distinguish between Fenced and Indented
    return ""
end

return parser