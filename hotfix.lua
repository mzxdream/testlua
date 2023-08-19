function update_func(env_f, g_f, name, deep)
    --取得原值所有的upvalue，保存起来
    local old_upvalue_map = {}
    for i = 1, math.huge do
        local name, value = debug.getupvalue(g_f, i)
        if not name then break end
        old_upvalue_map[name] = value
    end
    --遍历所有新的upvalue，根据名字和原值对比，如果原值不存在则进行跳过，如果为其它值则进行遍历env类似的步骤
    for i = 1, math.huge do
        local name, value = debug.getupvalue(env_f, i)
        if not name then break end
        local old_value = old_upvalue_map[name]
        if old_value then
            if type(old_value) ~= type(value) then
                debug.setupvalue(env_f, i, old_value)
            elseif type(old_value) == 'function' then
                update_func(value, old_value, name, deep..'  '..name..'  ')
            elseif type(old_value) == 'table' then
                update_table(value, old_value, name, deep..'  '..name..'  ')
                debug.setupvalue(env_f, i, old_value)
            else
                debug.setupvalue(env_f, i, old_value)
            end
        end
    end
end

local protection = {
    setmetatable = true,
    pairs = true,
    ipairs = true,
    next = true,
    require = true,
    _ENV = true,
}

--防止重复的table替换，造成死循环
local visited_sig = {}
function update_table(env_t, g_t, name, deep)
    --对某些关键函数不进行比对
    if protection[env_t] or protection[g_t] then return end
    --如果原值与当前值内存一致，值一样不进行对比
    if env_t == g_t then return end
    local signature = tostring(g_t)..tostring(env_t)
    if visited_sig[signature] then return end
    visited_sig[signature] = true
    --遍历对比值，如进行遍历env类似的步骤
    for name, value in pairs(env_t) do
        local old_value = g_t[name]
        if type(value) == type(old_value) then
            if type(value) == 'function' then
                update_func(value, old_value, name, deep..'  '..name..'  ')
                g_t[name] = value
            elseif type(value) == 'table' then
                update_table(value, old_value, name, deep..'  '..name..'  ')
            end
        else
            g_t[name] = value
        end
    end
    --遍历table的元表，进行对比
    local old_meta = debug.getmetatable(g_t)
    local new_meta = debug.getmetatable(env_t)
    if type(old_meta) == 'table' and type(new_meta) == 'table' then
        update_table(new_meta, old_meta, name..'s Meta', deep..'  '..name..'s Meta'..'  ' )
    end
end

function hotfix(chunk, check_name)
    local env = {}
    setmetatable(env, { __index = _G })
    local _ENV = env
    local f, err = load(chunk, check_name,  't', env)
    assert(f,err)
    local ok, err = pcall(f)
    assert(ok,err)

    for name, value in pairs(env) do
        local g_value = _G[name]
        if type(g_value) ~= type(value) then
            _G[name] = value
        elseif type(value) == 'function' then
            update_func(value, g_value, name, 'G'..'  ')
            _G[name] = value
        elseif type(value) == 'table' then
            update_table(value, g_value, name, 'G'..'  ')
        end
    end
end

function hotfix_file(name)
    local file_str
    local fp = io.open(name)
    if fp then
        io.input(name)
        file_str = io.read('*all')
        io.close(fp)
    end

    if not file_str then
        return -1
    end
    return hotfix(file_str, name)
end