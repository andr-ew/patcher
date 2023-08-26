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
    local args = args or {}
    local patcher = args.patcher or patcher
    local levels = args.levels or { 4, 15 }

    return function(dest_id, active_src_id, props)
        if active_src_id and (active_src_id ~= 'none') and crops.device == 'grid' then 
            local patched = patcher.get_assignment(dest_id) == active_src_id

            if props.size then
                if crops.mode == 'input' then
                    local x, y, z = table.unpack(crops.args) 
                    local n = Grid.util.xy_to_index(props, x, y)

                    if n and z>0 then 
                        if patched then
                            patcher.set_assignment('none', dest_id)
                        else
                            patcher.set_assignment(active_src_id, dest_id)
                        end
                    end
                else
                    props.levels = {
                        patched and levels[1] or 0,
                        levels[2]
                    }

                    _comp(props)
                end
            else
                if crops.mode == 'input' then
                    local x, y, z = table.unpack(crops.args) 

                    if x == props.x and y == props.y and z>0 then
                        if patched then
                            patcher.set_assignment('none', dest_id)
                        else
                            patcher.set_assignment(active_src_id, dest_id)
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

function Patcher.arc.destination(_comp, args)
    local args = args or {}
    local patcher = args.patcher or patcher
    local levels = args.levels or { 0, 4 }

    local remainder = 0.0

    return function(dest_id, active_src_id, props)
        if active_src_id and (active_src_id ~= 'none') and crops.device == 'arc' then 
            local patched = patcher.get_assignment(dest_id) == active_src_id

            if crops.mode == 'input' then
                local n, d = table.unpack(crops.args)

                if n == props.n then
                    local old = (patched and 1 or 0) + remainder
                    local new = old + (d * (props.sensitivity or 1/4))
                    local int, frac = math.modf(new)

                    if int >= 1 then
                        patcher.set_assignment(active_src_id, dest_id)
                    else
                        patcher.set_assignment('none', dest_id)
                    end

                    remainder = frac
                end
            elseif crops.mode == 'redraw' then
                do
                    local a = crops.handler

                    for x = 1,64 do
                        a:led(props.n, x, levels[patched and 2 or 1])
                    end
                end

                props.levels = { 0, props.levels[2] }

                _comp(props)
            end
        else
            _comp(props)
        end
    end
end

return Patcher
