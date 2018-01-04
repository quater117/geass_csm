--[[
=================================================================
Copyright (c) 2018 quater.
Licenced under the MIT licence. See LICENCE for more information.
=================================================================
--]]

local localplayer
local mod_storage = core.get_mod_storage()
local timestep = 1
local timer = 0
local running_script = {}
local environment_list = {}
local lua_environment
local name = 'lua_code'
local enable_callback_table_management = true
local callback_table = {}
local history = ''

local create_env
local env_settings

--local env_settings = function(env, title)
env_settings = function(env, title)
  env._halt = function()
    running_script[title] = false
  end
  env.require = function(to_load)
    if env._LOADED[to_load] ~= nil then
      return env._LOADED[to_load]
    end
    local script = mod_storage:get_string(to_load)
    local code, errors = loadstring(script)
    if errors then
      error(errors)
    end
    setfenv(code, env)
    local status, result = pcall(code)
    if not status then
      error(result)
    end
    if result == nil then
      result = true
    end
    env._LOADED[title] = result
    return result
  end
  if not enable_callback_table_management then
    return
  end
  callback_table[title] = callback_table[title] or {}
  local t = callback_table[title]
  for k, v in pairs(core) do
    local l = k:match('^register_(.*)')
    if l then
      local func = env.core[k]
      t[l] = t[l] or {}
      env.core[k] = function(fn)
        table.insert(t[l], fn)
        func(fn)
      end
    end
  end
end

--local create_env = function()
create_env = function()
  --local env = getfenv()
  local env = {}
  for k, v in pairs(_G) do
    env[k] = v
  end
  env._G = env
  env.mod_storage = mod_storage
  env.localplayer = localplayer
  env._running_script = running_script
  env._halt = function() end
  env._LOADED = {}
  env.require = function(title)
    if env._LOADED[title] ~= nil then
      return env._LOADED[title]
    end
    local script = mod_storage:get_string(title) or ''
    local code, errors = loadstring(script)
    if errors then
      error(errors)
    end
    --[[
    local title_env = environment_list[title]
    if not title_env then
      title_env = create_env()
      env_settings(title_env, title)
      environment_list[title] = title_env
    end
    setfenv(code, title_env)
    --]] setfenv(code, env)
    local status, result = pcall(code)
    if not status then
      error(result)
    end
    if result == nil then
      result = true
    end
    env._LOADED[title] = result
    return result
  end
  return env
end

local run = function(script, env)
  local byte_code, errors = loadstring(script)
  if errors then
    core.display_chat_message(core.colorize('red', 'Error in loading: ')
      .. errors)
    return nil, errors
  end
  if env then
    setfenv(byte_code, env)
  end
  local status, result = pcall(byte_code)
  if not status then
    core.display_chat_message(core.colorize('red', 'Error in execution: ')
      .. result)
    return nil, result
  end
  return result, nil
end

local save_title = function(title)
  local save = true
  local titles = mod_storage:get_string('titles') or ''
  for t in titles:gmatch('[^%s]+') do
    if t == title then
      save = false
      break
    end
  end
  if save then
    mod_storage:set_string('titles', titles .. ' ' .. title)
  end
end

core.register_on_connect(
function()
  running_script['on_join'] = true
  local lua_code = mod_storage:get_string('on_join') or ''
  if lua_code ~= '' then
    save_title('on_join')
  end
  localplayer = core.localplayer
end)

core.register_globalstep(
function(dtime)
  timer = timer + dtime
  if timer > timestep then
    timer = 0
    for title, bool in pairs(running_script) do
      local env = environment_list[title]
      if not env then
        env = create_env()
        env_settings(env, title)
        environment_list[title] = env
      end
      if bool then
        local lua_code = mod_storage:get_string(title) or ''
        --env_settings(env, title)
        local result, errors = run(lua_code, env)
        if errors then
          running_script[title] = false
        end
      end
    end
  end
end)

core.register_on_formspec_input(
function(form_name, fields)
  --[[
  core.display_chat_message('form_name: ' .. form_name)
  for k, v in pairs(fields) do
    core.display_chat_message('fields: ' .. k .. ': ' .. v)
  end
  -- ]]
  if form_name ~= 'lua_code' then
    return
  end
  if fields.run then
    running_script[name] = true
    local lua_code = fields.code or ''
    mod_storage:set_string(name, lua_code)
    local env = create_env()
    env_settings(env, name)
    environment_list[name] = env
    local result, errors = run(lua_code, env)
    if errors then
      running_script[name] = nil
    end
    save_title(name)
    return
  elseif fields.stop then
    running_script[name] = nil
    return
  elseif fields.apply then
    local lua_code = fields.code or ''
    mod_storage:set_string(name, lua_code)
    save_title(name)
    return
  elseif fields.help then
    local text =
      '-- Write code lua with a minetest environment\n\n' ..
      '-- commands:\n' ..
      '--   edit <title0>\n' ..
      '--       to edit the script titled <title0>\n' ..
      '--   run\n' ..
      '--       to run the current script\n' ..
      '--   run <title0> <title1> ... <titleN>\n' ..
      '--       to run the script titled <title0>, <title1>, ..., <titleN>\n' ..
      '--   halt\n' ..
      '--       to stop the current script\n' ..
      '--   halt <title0> <title1> ... <titleN>\n' ..
      '--       to stop the script titled <title0>, <title1>, ..., <titleN>\n'
      ..
      '--   load <title0>\n' ..
      '--       to load the script titled <title0>\n' ..
      '--   cat <title0>\n' ..
      '--       to disply the script titled <title0>\n' ..
      '--   title\n' ..
      '--       to display the title of current script\n' ..
      '--   copy <title0>\n' ..
      '--       to duplicate the current script with title <title0>\n' ..
      '--   remove <title0>\n' ..
      '--       to duplicate the current script with title <title0>\n' ..
      '--   unregister <title0> <title1> ... <titleN>\n' ..
      '--       if it is enabled then it remove every registered callback by\n'
      ..
      '--       the script titled <title0> <title1> ... <titleN>\n\n' ..
      '-- Example\n\n' ..
      't = t or 0\n' ..
      'core.display_chat_message(\'t = \' .. t)\n' ..
      't = t + 1\n' ..
      'if t > 8 then\n' ..
      '  _halt()\n' ..
      'end\n' ..
      '-- special functions and variables:\n' ..
      '-- function to stop the script:\n' ..
      '--     _halt()\n' ..
      '-- variable to access the mod_storage:\n' ..
      '--     mod_storage\n' ..
      '--'
      text = core.formspec_escape(text)
      local list = ''
      for word in text:gmatch('(.-)\n+') do
        list = list .. word .. ','
      end
      local form =
        'size[10, 8]' ..
        'textlist[-0.25, -0.25; 10.25, 8.5;help;' .. list .. ']'
      core.show_formspec('lua_help', form)
  end
end)

local formspec = function()
  local lua_code = mod_storage:get_string(name) or ''
  local code = core.formspec_escape(lua_code)
  local form = 
    'size[8, 8]' ..
    'textarea[0, -0.25; 8.5, 9;code;;' .. code .. ']' ..
    'button_exit[5.5, 7.5; 1.25, 1;run; Run]' ..
    'button[-0.25, 7.5; 1.25, 1;help; Help]' ..
    'button[4.25, 7.5; 1.25, 1;stop; Stop]' ..
    'button[6.75, 7.5; 1.5, 1;apply; Apply]'
  return form
end

core.register_chatcommand('lua', {
  description = 'Execute lua code',
  func = function(param)
    if not lua_environment then
      lua_environment = create_env()
    end
    --env_settings(env, title)
    run(param, lua_environment)
  end
})

core.register_chatcommand('luac', {
  description = 'Try: .luac help',
  func = function(param)
    history = history .. '.luac ' .. param .. '\n'
    local tokens = {}
    for token in param:gmatch('[^%s]+') do
      table.insert(tokens, token)
    end
    if tokens[1] == 'edit' then
      local title = tokens[2] or name
      name = title
    elseif tokens[1] == 'load' then
      local title = tokens[2] or ''
      if title == '' then
        core.display_chat_message(core.colorize('red', 'Error: ')
          .. 'title can\'t be empty')
      end
      name = title
      core.display_chat_message(core.colorize('yellow', 'Code loaded'))
      return
    elseif tokens[1] == 'save' then
      local title = tokens[2] or name
      local code = mod_storage:get_string(name) or ''
      mod_storage:set_string(title, code)
      save_title(title)
      core.display_chat_message(core.colorize('yellow', 'Code saved'))
      return
    elseif tokens[1] == 'title' then
      core.display_chat_message(core.colorize('yellow', 'Title: ') .. name)
      return
    elseif tokens[1] == 'remove' then
      local title = tokens[2] or ''
      if title == '' then
        core.display_chat_message(core.colorize('red', 'Error: ')
         ..'title can\'t be empty')
      end
      local titles = mod_storage:get_string('titles')
      local new_titles = 'titles'
      --titles = titles:gsub(title, ''); titles = titles:gsub('%s%s', ' ')
      for t in titles:gmatch('[^%s]+') do
        if t ~= title then
          new_titles = new_titles .. ' ' .. t
        end
      end
      mod_storage:set_string('titles', new_titles)
      mod_storage:set_string(title, nil)
      core.display_chat_message(core.colorize('yellow', 'Code removed'))
      return
    elseif tokens[1] == 'exec' then
      for i = 2, #tokens do
        local title = tokens[i]
        local env = create_env()
        environment_list[title] = env
        running_script[title] = true
        local code = mod_storage:get_string(title) or ''
        env_settings(env, title)
        local result, errors = run(code, env)
        if errors then
          core.display_chat_message(core.colorize('red', 'Error from: ')
            .. title)
          running_script[title] = nil
          return
        end
      end
      if #tokens == 1 then
        running_script[name] = true
        local env = create_env()
        environment_list[name] = env
        local code = mod_storage:get_string(name) or ''
        env_settings(env, name)
        run(code, env)
        if errors then
          core.display_chat_message(core.colorize('red', 'Error from: ')
            .. name)
          running_script[name] = false
          return
        end
      end
      return
    elseif tokens[1] == 'unregister' then
      if not enable_callback_table_management then
        core.display_chat_message(core.colorize('red',
          'This fonctionality is disable :('))
        return
      end
      for i = 2, #tokens do
        local title = tokens[i]
        local list = {}
        local t = callback_table[title]
        --core.display_chat_message(dump(t))
        if t then
          callback_table[title] = nil
          for i, v in pairs(t) do -- function's type, table
            --core.display_chat_message('i ' .. i .. ' type ' .. type(v))
            for j, w in ipairs(v) do -- index, function's address
              --core.display_chat_message('j ' .. j .. ' type ' .. type(w))
              local registered = core['registered_' .. i]
              for k, x in ipairs(registered) do
                if w == x then
                  table.remove(registered, k)
                end
              end
            end
          end
        end
        core.display_chat_message(core.colorize('yellow', 'All callbacks from ')
          .. core.colorize('cyan', title)
          .. core.colorize('yellow', ' are unregistered now'))
      end
      return
    elseif tokens[1] == 'cat' then
      local title = tokens[2] or name
      local code = mod_storage:get_string(title) or ''
      core.display_chat_message(code)
      return
    elseif tokens[1] == 'halt' then
      for i = 2, #tokens do
        local title = tokens[i]
        running_script[title] = nil
      end
      if #tokens == 1 then
        running_script[name] = nil
      end
      return
    elseif tokens[1] == 'help' then
      core.display_chat_message('type \'.luac\' and press \'Help\' button')
      return
    elseif tokens[1] == 'history' then
      core.display_chat_message(history)
      return
    elseif tokens[1] then
      core.display_chat_message(core.colorize('red', 'Unknown command: ')
        .. tokens[1])
      return
    end
    core.show_formspec('lua_code', formspec())
    return
  end
})

core.register_chatcommand('luaclear', {
  description = 'Clear the context',
  func = function(param)
    lua_environment = create_env()
    core.display_chat_message(core.colorize('yellow',
      'lua environment cleared'))
  end
})

core.display_chat_message('[CSM] loaded lua')

