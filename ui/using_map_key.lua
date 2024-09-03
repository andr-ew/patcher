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

    return function(dest_id, mode_map, props, label)
        if crops.mode == 'input' then
            _enc(dest_id, mode_map, props)
        else
            _screen(dest_id, mode_map, props, label)
        end
    end
end

function Patcher.key_screen.destination(_comp, args)
    local _key = Patcher.key.destination(_comp, args)
    local _screen = Patcher.screen.destination(_comp, args)

    return function(dest_id, mode_map, props, label)
        if crops.mode == 'input' then
            _key(dest_id, mode_map, props)
        else
            _screen(dest_id, mode_map, props, label)
        end
    end
end

function Patcher.enc.destination(_comp, args)
    local args = args or {}
    local patcher = args.patcher or patcher

    local _source = Enc.integer()

    return function(dest_id, mode_map, props)
        if mode_map and crops.mode == 'input' and crops.device == 'enc' then 
            if patcher.get_destination_name(dest_id) then
                local id_ass = patcher.get_assignment_param_id(dest_id)
                _source{
                    n = props.n, max = #params:lookup_param(id_ass).options,
                    state = crops.of_param(id_ass)
                }                
            end
        else
            _comp(props)
        end
    end
end

function Patcher.key.destination(_comp, args)
    local args = args or {}
    local patcher = args.patcher or patcher
    
    local _source = Key.integer()

    return function(dest_id, mode_map, props)
        if mode_map and crops.mode == 'input' and crops.device == 'key' then 
            if patcher.get_destination_name(dest_id) then
                local id_ass = patcher.get_assignment_param_id(dest_id)
                _source{
                    n_next = props.n or props.n_next, 
                    n_prev = props.n_prev,
                    max = #params:lookup_param(id_ass).options,
                    state = crops.of_param(id_ass)
                }                
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
    
    local _source = Screen.list()

    return function(dest_id, mode_map, props, label)
        if mode_map and crops.mode == 'redraw' and crops.device == 'screen' then 
            local name = label or patcher.get_destination_name(dest_id)
            if name then
                _source{
                    x = props.x, 
                    y = props.y,
                    font_face = props.font_face,
                    font_size = props.font_size,
                    margin = props.margin,
                    flow = props.flow,
                    font_headroom = props.font_headroom,
                    focus = 2,
                    levels = levels,
                    text = {
                        name, 
                        patcher.get_source_name(patcher.get_assignment_of_destination(dest_id))
                    },
                }
            end
        else
            _comp(props)
        end
    end
end

function Patcher.screen.last_connection(args)
    local args = args or {}
    local patcher = args.patcher or patcher

    return function(props)
        local last_dest, last_src = patcher.last_assignment.dest, patcher.last_assignment.src

        if crops.mode == 'redraw' and crops.device == 'screen' and last_dest and last_src then
            local levels = props.levels or { 10, 15 }

            
            local size = props.font_size or 8
            screen.font_face(props.font_face or 1)
            screen.font_size(size)
            screen.move(props.x_left, props.y)
            screen.level(levels[1])
            screen.text(patcher.get_destination_name(last_dest))
            
            local width = 6 + 4
            local mar = props.margin or 6
            screen.move(props.x_right + mar + width, props.y)
            screen.level(levels[2])
            screen.text(patcher.get_source_name(last_src))

            -- screen.font_face(49)
            -- screen.font_face(1)
            -- screen.font_size(size + 3)
            
            screen.level(levels[2])
            screen.move(props.x_right, props.y) -- + 2)
            screen.text("←") -- utf8.char(8592)

            screen.move(props.x_right + width, props.y - 2)
            screen.line_width(1)
            screen.line_rel(-width, 0)
            screen.stroke()
        end
    end
end

--(rest is TODO)

local t_on = 0.2
local t_off = t_on
local t_rest = 0.3

local blinks = {}

local function start_blink(src_index)
    blinks[src_index] = 0
    clock.run(function() while true do
        for i = 1,(src_index - 1) do
            blinks[src_index] = 1
            crops.dirty.grid = true
            clock.sleep(t_on)
            blinks[src_index] = 0
            crops.dirty.grid = true
            clock.sleep(t_off)
        end

        clock.sleep(t_rest)
    end end)
end
local function get_blink(src_index)
    if not blinks[src_index] then start_blink(src_index) end
    return blinks[src_index]
end

function Patcher.grid.destination(_comp, args)
    local args = args or {}
    local patcher = args.patcher or patcher
    local levels = args.levels or { { 4, 8 }, { 4, 8 } }

    return function(dest_id, mode_map, props)
        if mode_map and crops.device == 'grid' then 
            if patcher.get_destination_name(dest_id) then
                if crops.mode == 'input' then
                    if props.size then
                        local x, y, z = table.unpack(crops.args) 
                        local n = Grid.util.xy_to_index(props, x, y)

                        if n and z>0 then 
                            patcher.delta_assignment(dest_id, 1, true)
                        end
                    else
                        local x, y, z = table.unpack(crops.args) 

                        if x == props.x and y == props.y and z>0 then
                            patcher.delta_assignment(dest_id, 1, true)
                        end
                    end
                else
                    props.levels = props.levels or { 0, 15 }
                    local bl = get_blink(params:get(patcher.get_assignment_param_id(dest_id)))
                    props.levels[1] = levels[1] and levels[1][bl + 1] or props.levels[1]
                    props.levels[2] = levels[2] and levels[2][bl + 1] or props.levels[2]

                    _comp(props)
                end
            end
        else
            _comp(props)
        end
    end
end

--TODO
function Patcher.arc.destination(_comp, args)
    local args = args or {}
    local patcher = args.patcher or patcher
    local levels = args.levels or { 0, 4 }

    local remainder = 0.0

    return function(dest_id, mode_map, props)
        if mode_map and crops.device == 'arc' then 
            local patched = patcher.get_assignment_destination(dest_id) == mode_map

            if crops.mode == 'input' then
                local n, d = table.unpack(crops.args)

                if n == props.n then
                    local old = 0 + remainder
                    local new = old + (d * (args.sensitivity or 1/4))
                    local int, frac = math.modf(new)

                    

                    remainder = frac
                end
            elseif crops.mode == 'redraw' then
                do
                    local a = crops.handler

                    if false then for x = 1,64 do
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
