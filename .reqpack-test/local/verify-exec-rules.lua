local captured = nil

reqpack = {
  exec = {
    run = function(command)
      if command == "command -v 'dnf' >/dev/null 2>&1" then
        return { success = true, exitCode = 0, stdout = "", stderr = "" }
      end
      return { success = false, exitCode = 127, stdout = "", stderr = "unexpected global exec: " .. tostring(command) }
    end,
  },
}

package.loaded["run"] = nil
dofile("run.lua")

local context = {
  exec = {
    run = function(command, rules)
      captured = {
        command = command,
        rules = rules,
      }
      return { success = true, exitCode = 0, stdout = "Dependencies resolved.\nTransaction Summary\nRunning transaction\nComplete!\n", stderr = "" }
    end,
  },
  tx = {
    begin_step = function(_) end,
    success = function() end,
    failed = function(_) end,
  },
  events = {
    installed = function(_) end,
  },
}

local ok = plugin.install(context, {
  {
    name = "curl",
    version = "8.9.1",
  },
})

if not ok then
  error("install returned false")
end

if captured == nil then
  error("context.exec.run not called")
end

if captured.command ~= "dnf install -y 'curl-8.9.1'" then
  error("unexpected command: " .. tostring(captured.command))
end

if type(captured.rules) ~= "table" then
  error("exec rules missing")
end

if captured.rules.initial ~= "transaction" then
  error("unexpected initial state: " .. tostring(captured.rules.initial))
end

if type(captured.rules.rules) ~= "table" then
  error("rules.rules missing")
end

if #captured.rules.rules == 0 then
  error("rules.rules empty")
end

local saw_progress = false
for _, rule in ipairs(captured.rules.rules) do
  if type(rule) == "table" and type(rule.actions) == "table" then
    for _, action in ipairs(rule.actions) do
      if type(action) == "table" and action.type == "progress" then
        saw_progress = true
      end
    end
  end
end

if not saw_progress then
  error("no progress action found in rules")
end

print("exec rules verified")
