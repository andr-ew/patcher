local Patcher = {
    screen = {},
    enc = {},
    key = {},
    grid = {},
    arc = {},
    enc_screen = {},
    key_screen = {},
}

function Patcher.enc_screen.destination(_comp, args)
    local _enc = Patcher.enc.destination(_comp, args)
    local _screen = Patcher.screen.destination(_comp, args)

    return function(dest_id, active_src_id, props)
        if crops.mode == 'input' then
            _enc(dest_id, active_src_id, props)
        else
            _screen(dest_id, active_src_id, props)
        end
    end
end

function Patcher.key_screen.destination(_comp, args)
    local _key = Patcher.key.destination(_comp, args)
    local _screen = Patcher.screen.destination(_comp, args)

    return function(dest_id, active_src_id, props)
        if crops.mode == 'input' then
            _key(dest_id, active_src_id, props)
        else
            _screen(dest_id, active_src_id, props)
        end
    end
end

function Patcher.enc.destination(_comp, args)
    local args = args or {}
    local patcher = args.patcher or patcher

    local remainder = 0.0

    return function(dest_id, active_src_id, props)
        if 
            active_src_id and (active_src_id ~= 'none') 
            and crops.mode == 'input' and crops.device == 'enc'
        then 
            local n, d = table.unpack(crops.args)

            if n == props.n then
                local patched = patcher.get_assignment_destination(dest_id) == active_src_id

                local old = (patched and 1 or 0) + remainder
                local new = old + ((d > 0 and 1 or -1) * 1/2)
                local int, frac = math.modf(new)

                if int >= 1 then
                    patcher.set_assignment(active_src_id, dest_id)
                else
                    patcher.set_assignment('none', dest_id)
                end

                remainder = frac
            end
        else
            _comp(props)
        end
    end
end

function Patcher.key.destination(_comp, args)
    local args = args or {}
    local patcher = args.patcher or patcher

    return function(dest_id, active_src_id, props)
        if 
            active_src_id and (active_src_id ~= 'none') 
            and crops.mode == 'input' and crops.device == 'key'
        then 
            local n, z = table.unpack(crops.args) 

            if n == props.n and z>0 then 
                if patched then
                    patcher.set_assignment('none', dest_id)
                else
                    patcher.set_assignment(active_src_id, dest_id)
                end
            end
        else
            _comp(props)
        end
    end
end

function Patcher.screen.destination(_comp, args)
    local args = args or {}
    local patcher = args.patcher or patcher
    local levels = args.levels or { 4, 15 }

    return function(dest_id, active_src_id, props)
        if
            active_src_id and (active_src_id ~= 'none') 
            and crops.mode == 'redraw' and crops.device == 'screen' 
        then 
            local patched = patcher.get_assignment_destination(dest_id) == active_src_id

            local l = patched and levels[2] or levels[1]
            if props.levels then
                props.levels[2] = l
            elseif props.level then
                props.level = l
            end
        end
        
        _comp(props)
    end
end

function Patcher.grid.destination(_comp, args)
    local args = args or {}
    local patcher = args.patcher or patcher
    local levels = args.levels or { 4, 15 }

    return function(dest_id, active_src_id, props)
        if active_src_id and (active_src_id ~= 'none') and crops.device == 'grid' then 
            local patched = patcher.get_assignment_destination(dest_id) == active_src_id

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
                    if props.levels then props.levels[1] = patched and levels[1] or 0 end

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
                    if props.levels then props.levels[1] = patched and levels[1] or 0 end

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
            local patched = patcher.get_assignment_destination(dest_id) == active_src_id

            if crops.mode == 'input' then
                local n, d = table.unpack(crops.args)

                if n == props.n then
                    local old = (patched and 1 or 0) + remainder
                    local new = old + (d * (args.sensitivity or 1/4))
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

                    if patched then for x = 1,64 do
                        a:led(props.n, x, levels[2])
                    end end
                end

                if props.levels then props.levels[1] = 0 end

                _comp(props)
            end
        else
            _comp(props)
        end
    end
end

return Patcher
