local CommonUtils = {}


function CommonUtils.get_table_str_repr(t)
    local out = ""
    for k, v in ipairs(t) do
        out = out .. tostring(k) .. ": " .. tostring(v) .. "\n"
    end

    return out
    
end

return CommonUtils
