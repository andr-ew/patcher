local cs = require 'controlspec'

local sources = {}
local destinations = {}

local src_values = {}
local dest_values = {}

local src_assignments = {}
local dest_assignments = {}

local last_assignment = { src = nil, dest = nil }

local src_names = {}
local dest_names = {}

local src_assignment_callbacks = {}
local src_thresholds = {}

local dest_stream_actions = {}
local dest_change_actions = {}
--TODO: dest_window_actions
local dest_getters = {}
local dest_types = {}
local dest_modes = {}
local dest_directions = {}

local pfix_mod_source = 'mod_source_'

local do_nothing

local patcher = { 
    sources = sources, destinations = destinations, 
    src_values = src_values, dest_values = dest_values,
    src_names = src_names, dest_names = dest_names,
    src_assignments = src_assignments, dest_assignments = dest_assignments,
    last_assignment = last_assignment,
    dest_stream_actions = dest_stream_actions, dest_getters = dest_getters, dest_types = dest_types,
    src_thresholds = src_thresholds,
}

function patcher.add_source(args)
    local src_id = args.id
    local src_name = args.name or src_id
    local default = args.default or 0
    local trigger_threshold = args.trigger_threshold or 0.1
    local assignment_callback = args.assignment_callback or function() end

    table.insert(sources, src_id)
    table.insert(src_names, src_name)
    src_values[src_id] = default
    src_assignments[src_id] = {}
    src_thresholds[src_id] = trigger_threshold
    src_assignment_callbacks[src_id] = assignment_callback

    local function stream(src_value)
        local last = src_values[src_id] or 0
        src_values[src_id] = src_value

        for _,dest_id in ipairs(src_assignments[src_id]) do
            dest_stream_actions[dest_id](src_value, last, trigger_threshold)
        end
    end
    local function change(src_state)
        src_values[src_id] = src_state and 1 or 0

        for _,dest_id in ipairs(src_assignments[src_id]) do
            dest_change_actions[dest_id](src_state)
        end
    end

    return stream, change
end
        

do
    local stream = patcher.add_source{ 
        name = 'none', 
        id = 'none', 
        default = 0, 
        trigger_threshold = 0, 
    }

    do_nothing = function() stream(0) end
end

function patcher.add_destination(args)
    local typ = args.type
    local behavior = args.behavior
    local dest_id = args.id
    local dest_name = args.name or dest_id
    local action = args.action
    local spec = args.controlspec or cs.new()
    local default = args.controlspec and args.controlspec.default or args.default or 0
    local min = args.min
    local max = args.max
    local option_count = #(args.options or {})
    
    local mode = 'stream'
    local direction = 'both'

    if typ == 'binary' or typ == params.tBINARY then
        mode = 'change'

        if behavior == 'trigger' then
            direction = 'rising'
        end
    end

    table.insert(destinations, dest_id)
    dest_names[dest_id] = dest_name
    dest_assignments[dest_id] = 'none'
    dest_types[dest_id] = typ
    dest_values[dest_id] = default
    dest_modes[dest_id] = mode
    dest_directions[dest_id] = direction

    if typ == 'control' or typ == params.tCONTROL then
        dest_stream_actions[dest_id] = function(src_value, src_value_last, trigger_threshold)
            local dest_value = dest_values[dest_id]

            action(util.clamp(src_value + dest_value, spec.minval, spec.maxval))
        end
        dest_getters[dest_id] = function()
            local dest_value = dest_values[dest_id]

            local src_id = dest_assignments[dest_id]
            local src_value = src_values[src_id]

            return util.clamp(src_value + dest_value, spec.minval, spec.maxval)
        end

        return function(dest_value)
            dest_values[dest_id] = dest_value

            local src_id = dest_assignments[dest_id]
            local src_value = src_values[src_id]

            action(util.clamp(src_value + dest_value, spec.minval, spec.maxval))
        end
    elseif typ == 'number' or typ == params.tNUMBER then
        dest_stream_actions[dest_id] = function(src_value, src_value_last, trigger_threshold)
            local dest_value = dest_values[dest_id]

            if math.floor(src_value) ~= math.floor(src_value_last) then
                action(util.clamp(math.floor(src_value + dest_value), min, max))
            end
        end
        dest_getters[dest_id] = function()
            local dest_value = dest_values[dest_id]

            local src_id = dest_assignments[dest_id]
            local src_value = src_values[src_id]

            return util.clamp(math.floor(src_value + dest_value), min, max)
        end

        return function(dest_value)
            dest_values[dest_id] = dest_value

            local src_id = dest_assignments[dest_id]
            local src_value = src_values[src_id]

            action(util.clamp(math.floor(src_value + dest_value), min, max))
        end
    elseif typ == 'option' or typ == params.tOPTION then
        dest_stream_actions[dest_id] = function(src_value, src_value_last, trigger_threshold)
            local dest_value = dest_values[dest_id]

            if math.floor(src_value) ~= math.floor(src_value_last) then
                action(util.clamp(math.floor(src_value + dest_value), 1, option_count))
            end
        end
        dest_getters[dest_id] = function()
            local dest_value = dest_values[dest_id]

            local src_id = dest_assignments[dest_id]
            local src_value = src_values[src_id]

            return util.clamp(math.floor(src_value + dest_value), 1, option_count)
        end

        return function(dest_value)
            dest_values[dest_id] = dest_value

            local src_id = dest_assignments[dest_id]
            local src_value = src_values[src_id]

            action(util.round(util.clamp(src_value + dest_value, 1, option_count)))
        end
    elseif typ == 'binary' or typ == params.tBINARY then
        if behavior == 'momentary' or behavior == 'toggle' then
            dest_stream_actions[dest_id] = function(src_value, src_value_last, trigger_threshold)
                local src_gate = src_value > trigger_threshold and 1 or 0
                local src_gate_last = src_value_last > trigger_threshold and 1 or 0

                if src_gate ~= src_gate_last then
                    local dest_gate = dest_values[dest_id]

                    action(src_gate | dest_gate)
                end
            end
            dest_change_actions[dest_id] = function(src_state)
                local dest_gate = dest_values[dest_id]
                local src_gate = src_state and 1 or 0

                action(src_gate | dest_gate)
            end
            dest_getters[dest_id] = function()
                local dest_value = dest_values[dest_id]

                local src_id = dest_assignments[dest_id]
                local src_value = src_values[src_id]
                local src_threshold = src_thresholds[src_id]

                local src_gate = src_value > src_threshold and 1 or 0
                local dest_gate = dest_values[dest_id]
                    
                return src_gate | dest_gate
            end

            return function(dest_value)
                dest_values[dest_id] = dest_value

                local src_id = dest_assignments[dest_id]
                local src_value = src_values[src_id]

                action(math.floor(util.clamp(src_value + dest_value, 0, 1)))
            end
        elseif behavior == 'trigger' then
            dest_stream_actions[dest_id] = function(src_value, src_value_last, trigger_threshold)
                if
                    (src_value > trigger_threshold)
                    and (src_value_last < trigger_threshold)
                then 
                    action() 
                end
            end
            dest_change_actions[dest_id] = function(state)
                if state then action() end
            end
            dest_getters[dest_id] = function() end

            return action
        end
    end
end

function patcher.add_destination_and_param(args)
    local param_action = patcher.add_destination(args)
    args.action = param_action
    params:add(args)
end

function patcher.add_assignment_params(param_action)
    for _,this_dest_id in ipairs(destinations) do
        params:add{
            name = dest_names[this_dest_id], id = pfix_mod_source..this_dest_id, 
            type = 'option', options = src_names, default = 1,
            action = function(v)
                local src_id = sources[v]

                --update dest_assignments
                local last_src_id = dest_assignments[this_dest_id]
                dest_assignments[this_dest_id] = src_id

                --update src_assignments
                for i,dests in pairs(src_assignments) do for ii,dest in ipairs(dests) do
                    if dest == this_dest_id then
                        table.remove(dests, ii)
                        break
                    end
                end end
                table.insert(src_assignments[src_id], this_dest_id)

                last_assignment.src = src_id
                last_assignment.dest = this_dest_id

                if src_id == 'none' then
                    src_assignment_callbacks[last_src_id]('none', '')

                    do_nothing()
                else
                    local assignment_mode = 'change'
                    local assignment_direction = 'rising'
            
                    for _,dest_id in ipairs(src_assignments[src_id]) do
                        local dest_mode = dest_modes[dest_id]
                        local dest_direction = dest_directions[dest_id]

                        if dest_mode == 'stream' then
                            assignment_mode = 'stream'
                            break
                        elseif dest_mode == 'change' and dest_direction == 'both' then
                            assignment_direction = 'both'
                            break 
                        end
                    end

                    src_assignment_callbacks[src_id](assignment_mode, assignment_direction)
                end

                param_action()
            end
        }
    end
end

function patcher.set_assignment(src_id, dest_id)
    params:set(pfix_mod_source..dest_id, tab.key(sources, src_id))
end
function patcher.delta_assignment(dest_id, d, wrap)
    local id = pfix_mod_source..dest_id
    local new = params:get(id) + d
    if wrap then 
        new = util.wrap(new, 1, #params:lookup_param(id).options) 
    end
    params:set(id, new)
end
function patcher.get_assignment_of_destination(dest_id)
    return dest_assignments[dest_id]
end
function patcher.get_assignments_of_source(src_id)
    return src_assignments[src_id]
end
function patcher.get_assignment_param_id(dest_id)
    return pfix_mod_source..dest_id
end
function patcher.get_value_by_destination(dest_id)
    return dest_getters[dest_id]()
end
function patcher.get_source_value_by_destination(dest_id)
    return src_values[dest_assignments[dest_id]]
end
function patcher.get_destination_name(dest_id)
    return dest_names[dest_id]
end
function patcher.get_source_name(src_id)
    return src_names[tab.key(sources, src_id)]
end
--TODO: remove eventually
patcher.get_assignment_destination = patcher.get_assignment_of_destination
patcher.get_assignments_source = patcher.get_assignments_of_source
patcher.get_value = patcher.get_value_by_destination
patcher.get_mod_value = patcher.get_source_value_by_destination

do
    patcher.crow = {}

    local needs_re_enable = false

    -- src: https://github.com/monome/norns/blob/e8ae36069937df037e1893101e73bbdba2d8a3db/lua/core/crow.lua#L14
    local function re_enable_clock_source_crow()
        if params.lookup["clock_source"] then
            if params:string("clock_source") == "crow" then
                norns.crow.clock_enable()
            end
        end
    end

    function patcher.crow.add_source(input, time, threshold, hysteresis)
        time = time or 0.01
        threshold = threshold or 0.1
        hysteresis = hysteresis or 0.1

        local function assignment_callback(mode, direction)
            if mode == 'stream' then
                crow.input[input].mode('stream', time)
            elseif mode == 'change' then
                crow.input[input].mode('change', threshold, hysteresis, direction)
            elseif mode == 'none' then
                crow.input[input].mode('none')
            end
        
            if input == 1 then
                if mode == 'none' and needs_re_enable then
                    re_enable_clock_source_crow()
                    needs_re_enable = false
                else needs_re_enable = true end
            end
        end
        
        local stream, change = patcher.add_source{ 
            name = 'crow '..input, 
            id = 'crow_'..input, 
            default = 0, 
            trigger_threshold = threshold, 
            assignment_callback = assignment_callback
        }

        local function add_action()
            crow.input[input].stream = stream
            crow.input[input].change = change
        end

        return add_action
    end

    --TODO
    function patcher.crow.add_destination(input)
    end
end

return patcher
