local Utils = {}


function Utils.get_container_count(track, addrs)
    if track == nil or addrs == nil then return nil end
    local ok, cnt_str = reaper.TrackFX_GetNamedConfigParm(track, addrs, "container_count")
    if not ok then return nil end
    return tonumber(cnt_str) or 0
end


function Utils.is_container(track, addrs)
    return Utils.get_container_count(track, addrs) ~= nil
end



function Utils.enumerate_container_tree_nodes(track, cont_addrs, level)
    -- level - recursion depth
    -- level == -1 → unlimited
    -- level == 0 → return {} (no descendants)
    -- level == 1 → direct children only
    -- level > 1 → recurse that many levels
    local container_count = Utils.get_container_count(track, cont_addrs)

    if container_count == nil then return nil end

    local children_nodes = {}

    if level == 0 then return children_nodes end
    if level == nil then level = -1 end


    local function enum_children(addrs, depth_left, cur_depth)
        local node = {addrs = addrs, depth = cur_depth}
        children_nodes[#children_nodes+1] = node


        if depth_left ~= -1 then
            depth_left = depth_left - 1
            if depth_left == 0 then return end
        end


        local container_count = Utils.get_container_count(track, addrs)
        if container_count == nil or container_count == 0 then return end

        for i = 0, container_count - 1 do
            local ok, child_addrs_str = reaper.TrackFX_GetNamedConfigParm(track, addrs, "container_item." .. i)
            if ok then
                local child_addrs = tonumber(child_addrs_str)
                if child_addrs ~= nil then
                    enum_children(child_addrs, depth_left, cur_depth + 1)
                end
            end
                
        end

    end

    for i = 0, container_count - 1 do
        local ok, child_addrs_str = reaper.TrackFX_GetNamedConfigParm(track, cont_addrs, "container_item." .. i)
        if ok then
            local child_addrs = tonumber(child_addrs_str)
            if child_addrs ~= nil then
                enum_children(child_addrs, level, 1)
            end
        end
    end
    
    return children_nodes
end


function Utils.find_child_slot(track, parent_addr, child_addr)
    local ok, cnt_str = reaper.TrackFX_GetNamedConfigParm(track, parent_addr, "container_count")
    if not ok then return nil end
    local cnt = tonumber(cnt_str) or 0

    for i = 0, cnt - 1 do
        local ok2, addr_str = reaper.TrackFX_GetNamedConfigParm(track, parent_addr, "container_item." .. i)
        if ok2 and tonumber(addr_str) == child_addr then
            return i
        end
    end
    return nil
end


return Utils
