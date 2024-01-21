local cs = require 'controlspec'

local sources = { 'none' }
local destinations = {}

local src_values = { none = 0 }
local dest_values = {}

local src_assignments = { none = {} }
local dest_assignments  = {}

local dest_actions = {}
local dest_types = {}

local pfix_mod_source = 'mod_source_'

local patcher = { 
    sources = sources, destinations = destinations, 
    src_values = src_values, dest_values = dest_values,
    src_assignments = src_assignments, dest_assignments = dest_assignments,
    dest_actions = dest_actions, dest_types = dest_types,
}

function patcher.add_source(src_id, default, trigger_threshold)
    table.insert(sources, src_id)
    src_values[src_id] = default or 0
    src_assignments[src_id] = {}

    local thresh = trigger_threshold or 0

    return function(src_value)
        local last = src_values[src_id] or 0
        src_values[src_id] = src_value

        for _,dest_id in ipairs(src_assignments[src_id]) do
            dest_actions[dest_id](src_value, last, thresh)
        end
    end
end

function patcher.add_destination(args)
    local typ = args.type
    local behavior = args.behavior
    local dest_id = args.id
    local default = args.default or 0
    local action = args.action
    local spec = args.controlspec or cs.new()
    local min = args.min
    local max = args.max
    local option_count = #(args.options or {})

    table.insert(destinations, dest_id)
    dest_assignments[dest_id] = 'none'
    dest_types[dest_id] = typ
    dest_values[dest_id] = default or 0
        
    if typ == 'control' then
        dest_actions[dest_id] = function(src_value, src_value_last, trigger_threshold)
            local dest_value = dest_values[dest_id]

            action(util.clamp(src_value + dest_value, spec.minval, spec.maxval))
        end

        return function(dest_value)
            dest_values[dest_id] = dest_value

            local src_id = dest_assignments[dest_id]
            local src_value = src_values[src_id]

            action(util.clamp(src_value + dest_value, spec.minval, spec.maxval))
        end
    elseif typ == 'number' then
        dest_actions[dest_id] = function(src_value, src_value_last, trigger_threshold)
            local dest_value = dest_values[dest_id]

            if math.floor(src_value) ~= math.floor(src_value_last) then
                action(util.round(util.clamp(src_value + dest_value, min, max)))
            end
        end

        return function(dest_value)
            dest_values[dest_id] = dest_value

            local src_id = dest_assignments[dest_id]
            local src_value = src_values[src_id]

            action(util.round(util.clamp(src_value + dest_value, min, max)))
        end
    elseif typ == 'option' then
        dest_actions[dest_id] = function(src_value, src_value_last, trigger_threshold)
            local dest_value = dest_values[dest_id]

            if math.floor(src_value) ~= math.floor(src_value_last) then
                action(util.round(util.clamp(src_value + dest_value, 1, option_count)))
            end
        end

        return function(dest_value)
            dest_values[dest_id] = dest_value

            local src_id = dest_assignments[dest_id]
            local src_value = src_values[src_id]

            action(util.round(util.clamp(src_value + dest_value, 1, option_count)))
        end
    elseif typ == 'binary' then
        --TODO
        
        if behavior == 'momentary' then
        elseif behavior == 'toggle' then
        elseif behavior == 'trigger' then
        end
    end
end

--TODO: rename 'add_destination_and_param'
-- function patcher.add_source_and_param(args)
--     params:add(args)
    
--     local typ
--     if args.type == "number" then typ = 'integer'
--     elseif args.type == "option" then typ = 'integer'
--     elseif args.type == "control" then typ = 'decimal'
--     elseif args.type == "trigger" then typ = 'trigger'
--     elseif args.type == "binary" then
--         if args.behavior == "trigger" then typ = 'trigger'
--         else typ = 'integer' end
--     end

--     patcher.add_destination(typ, args.id, args.action)
-- end

-- function patcher.add_destination(typ, dest_id, action)
--     table.insert(destinations, dest_id)
--     types[dest_id] = typ
--     actions[dest_id] = action or function() end 
-- end


-- function patcher.set_source(src_id, src_value, trigger_threshold)
--     -- local last = src_values[src_id]
--     -- values[src_id] = value
    
--     for _,dest_id in ipairs(src_assignments[src_id]) do
--         -- if types[dest_id] == 'decimal' then
--         --     actions[dest_id](value, ...)
--         -- elseif types[dest_id] == 'integer' and math.floor(last) ~= math.floor(value) then
--         --     actions[dest_id](math.floor(value), ...)
--         -- elseif types[dest_id] == 'trigger' then
--         -- end

--         dest_actions[dest_id](src_value, trigger_threshold)
--     end
-- end

-- function patcher.get_destination(dest_id)
--     local src_id = sources[params:get(pfix_mod_source..dest_id)]

--     return values[src_id]
-- end

-- patcher.destination_last_vals = {}

-- function patcher.destination_poll_for_threshold_crossing(dest_id, threshold)
--     local new_v = patcher.get_destination(dest_id)
--     local old_v = patcher.destination_last_vals[dest_id] or 0

--     local crossing = (old_v < threshold) and (new_v > threshold)

--     patcher.destination_last_vals[dest_id] = new_v

--     return crossing
-- end

-- function patcher.get_destination_plus_param(dest_id, param_id, paramset)
--     param_id = param_id or dest_id
--     paramset = paramset or params

--     local param = paramset:lookup_param(param_id)
--     local dv = patcher.get_destination(dest_id)
--     local pv = paramset:get(param_id)

--     if param.t == paramset.tCONTROL then
--         local spec = param.controlspec
--         return util.clamp(pv + dv, spec.minval, spec.maxval)
--     elseif param.t == paramset.tNUMBER then
--         return util.round(util.clamp(pv + dv, param.min, param.max))
--     elseif param.t == paramset.tOPTION then
--         return util.round(util.clamp(pv + dv, 1, #param.options))
--     elseif param.t == paramset.tBINARY and (
--         param.behavior == 'momentary'
--         or param.behavior == 'toggle'
--     ) then
--         return math.floor(util.clamp(pv + dv, 0, 1))
--     elseif 
--         (param.t == paramset.tBINARY and param.behavior == 'trigger')
--         or param.t == paramset.tTRIGGER
--     then
--         -- use patcher.destination_poll_for_threshold_crossing()
--     end
-- end

--TODO: rename 'add_assignment_params' (typo)
function patcher.add_assginment_params(action)
    for _,dest_id in ipairs(destinations) do
        params:add{
            name = dest_id, id = pfix_mod_source..dest_id, 
            type = 'option', options = sources, default = 1,
            action = function(v)
                local src_id = sources[v]

                --update dest_assignments
                dest_assignments[dest_id] = src_id

                --update src_assignments
                for i,dests in pairs(src_assignments) do for ii,dest in ipairs(dests) do
                    if dest == dest_id then
                        table.remove(dests, ii)
                        break
                    end
                end end
                table.insert(src_assignments[src_id], dest_id)
            end
        }
    end
end
function patcher.set_assignment(src_id, dest_id)
    params:set(pfix_mod_source..dest_id, tab.key(sources, src_id))
end
function patcher.get_assignment(dest_id)
    return sources[params:get(pfix_mod_source..dest_id)]
end

return patcher
