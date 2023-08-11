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
    table.insert(destinations, src_id)
    actions[dest_id] = action or function() end 
end

function patcher.set(src_id, value, ...)
    values[src_id] = value
    
    for _,dest_id in ipairs(destinations) do
        if sources[params:get(pfix_mod_source..dest_id)] == src_id then 
            actions[dest_id](value, ...)
        end
    end
end

function patcher.get(dest_id)
    local src_id = sources[params:get(pfix_mod_source..dest_id)]

    return values[src_id]
end

function patcher.add_params(action)
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
