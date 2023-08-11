local Patcher = {
    screen = {},
    enc = {},
    key = {},
    grid = {},
    arc = {},
}

function Patcher.enc.destination(_comp, p)
    local patcher = p or patcher

    return function(dest_id, is_patching, props)
    end
end

function Patcher.grid.destination(_comp, args)
    local patcher = args.patcher or patcher
    local levels = args.levels or { 4, 15 }

    return function(dest_id, active_src_id, props)
        if active_src_id and (active_src_id ~= 'none') and crops.device == 'grid' then 
            local patched = patcher.get_assignment(dest_id) ~= 'none'

            if props.size then
                if crops.mode == 'input' then
                    local x, y, z = table.unpack(crops.args) 
                    local n = Grid.util.xy_to_index(props, x, y)

                    if n and z>0 then 
                        if patched then
                            patcher.set_assignment(active_src_id, dest_id)
                        else
                            patcher.set_assignment('none', dest_id)
                        end
                    end
                else
                    props.levels[1] = patched and levels[1] or 0
                    props.levels[2] = levels[2]

                    _comp(props)
                end
            else
                if crops.mode == 'input' then
                    local x, y, z = table.unpack(crops.args) 

                    if x == props.x and y == props.y and z>0 then
                        if patched then
                            patcher.set_assignment(active_src_id, dest_id)
                        else
                            patcher.set_assignment('none', dest_id)
                        end
                    end
                else
                    props.level = patched and levels[2] or levels[1]

                    _comp(props)
                end
            end
        else
            _comp(props)
        end
    end
end

return Patcher
