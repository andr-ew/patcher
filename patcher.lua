local sources = { 'none' }
local values = { none = 0 }

local destinations = {}
local actions = {}

local pfix_mod_source = 'mod_source_'

local patcher = { 
    sources = sources, values = values, destinations = destinations, actions = actions 
}

function patcher.add_source(src_id, default)
    table.insert(sources, src_id)
    values[src_id] = default or 0
end

function patcher.add_destination(dest_id, action)
    table.insert(destinations, dest_id)
    actions[dest_id] = action or function() end 
end

function patcher.set_source(src_id, value, ...)
    values[src_id] = value
    
    for _,dest_id in ipairs(destinations) do
        if sources[params:get(pfix_mod_source..dest_id)] == src_id then 
            actions[dest_id](value, ...)
        end
    end
end

function patcher.get_destination(dest_id)
    local src_id = sources[params:get(pfix_mod_source..dest_id)]

    return values[src_id]
end

patcher.destination_last_vals = {}

function patcher.destination_poll_for_threshold_crossing(dest_id, threshold)
    local new_v = patcher.get_destination(dest_id)
    local old_v = patcher.destination_last_vals[dest_id] or 0

    local crossing = (old_v < threshold) and (new_v > threshold)

    patcher.destination_last_vals[dest_id] = new_v

    return crossing
end

function patcher.get_destination_plus_param(dest_id, param_id, paramset)
    param_id = param_id or dest_id
    paramset = paramset or params

    local param = paramset:lookup_param(param_id)
    local dv = patcher.get_destination(dest_id)
    local pv = paramset:get(param_id)

    if param.t == paramset.tCONTROL then
        local spec = param.controlspec
        return util.clamp(pv + dv, spec.minval, spec.maxval)
    elseif param.t == paramset.tNUMBER then
        return util.round(util.clamp(pv + dv, param.min, param.max))
    elseif param.t == paramset.tOPTION then
        return util.round(util.clamp(pv + dv, 1, #param.options))
    elseif param.t == paramset.tBINARY and (
        param.behavior == 'momentary'
        or param.behavior == 'toggle'
    ) then
        return math.floor(util.clamp(pv + dv, 0, 1))
    elseif 
        (param.t == paramset.tBINARY and param.behavior == 'trigger')
        or param.t == paramset.tTRIGGER
    then
        -- use patcher.destination_poll_for_threshold_crossing()
    end
end

function patcher.add_assginment_params(action)
    for _,dest_id in ipairs(destinations) do
        params:add{
            name = dest_id, id = pfix_mod_source..dest_id, 
            type = 'option', options = sources, default = 1,
            action = action 
        }
    end
end
function patcher.set_assignment(src_id, dest_id)
    params:set(pfix_mod_source..dest_id, tab.key(sources, src_id))
end
function patcher.get_assignment(dest_id)
    return params:get(pfix_mod_source..dest_id)
end

return patcher
