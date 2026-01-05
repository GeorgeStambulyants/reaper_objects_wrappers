local CommonUtils = {}


local function dump_table(t, indent, visited)
    indent = indent or 0
    visited = visited or {}

    if visited[t] then
        reaper.ShowConsoleMsg(string.rep(" ", indent) .. "*recursive*\n")
        return
    end
    visited[t] = true

    for k, v in pairs(t) do
        local prefix = string.rep(" ", indent) .. tostring(k) .. " = "
        if type(v) == "table" then
            reaper.ShowConsoleMsg(prefix .. "{\n")
            dump_table(v, indent + 2, visited)
            reaper.ShowConsoleMsg(string.rep(" ", indent) .. "}\n")
        else
            reaper.ShowConsoleMsg(prefix .. tostring(v) .. "\n")
        end
    end
end

function CommonUtils.print_table(t, title)
    if title then
        reaper.ShowConsoleMsg("\n" .. title .. ":\n")
    end
    dump_table(t)
end


return CommonUtils
