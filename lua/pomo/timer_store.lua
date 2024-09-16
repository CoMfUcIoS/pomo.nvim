---This class is used to store all active timers.
---@class pomo.TimerStore
---@field timers pomo.Timer[]
local TimerStore = {}
---Initialize a new `pomo.TimerStore`.
---@return pomo.TimerStore

local filename = vim.fn.stdpath "state" .. "/pomo_timers.txt"

local config

TimerStore.new = function(configuration)
  config = configuration
  local self = setmetatable({}, { __index = TimerStore })
  self.timers = {}
  if filename then
    local file = io.open(filename, "r")
    if file then
      file:close()
      self:load_from_file()
    else
      print "File not found, creating a new one."
      self:save_to_file()
    end
  else
    print "No filename provided"
  end
  return self
end

---Get the first available ID for a new timer.
---@return integer
TimerStore.first_available_id = function(self)
  for i = 1, #self.timers do
    if self.timers[i] == nil then
      return i
    end
  end
  return #self.timers + 1
end

---Get the number of timers currently stored.
---@return integer
TimerStore.len = function(self)
  return vim.tbl_count(self.timers)
end

---Check if the timer store is empty.
---@return boolean
TimerStore.is_empty = function(self)
  return self:len() == 0
end

---Store a new timer.
---@param timer pomo.Timer
TimerStore.store = function(self, timer)
  if timer.id == nil then
    timer.id = self:first_available_id()
  end
  self.timers[timer.id] = timer
  if filename then
    self:save_to_file()
  end
end

---Remove a timer from the store.
---@param timer integer|pomo.Timer
TimerStore.remove = function(self, timer)
  ---@type integer
  local timer_id
  if type(timer) == "number" then
    timer_id = timer
  else
    timer_id = timer.id
  end

  self.timers[timer_id] = nil
  if filename then
    self:save_to_file()
  end
end

---Get a timer from the store by its ID.
---@param timer_id integer
---@return pomo.Timer|?
TimerStore.get = function(self, timer_id)
  return self.timers[timer_id]
end

---Get the latest timer (last one started).
---@return pomo.Timer|?
TimerStore.get_latest = function(self)
  ---@type pomo.Timer|?
  local latest_timer
  ---@type integer|?
  local latest_start_time

  for _, t in pairs(self.timers) do
    if latest_timer == nil or latest_start_time == nil or t.start_time == nil or t.start_time > latest_start_time then
      latest_timer = t
      latest_start_time = t.start_time
    end
  end

  return latest_timer
end

---Get the first timer to finish next (minimum time remaining) out of all active timers.
---@return pomo.Timer|?
TimerStore.get_first_to_finish = function(self)
  ---@type pomo.Timer|?
  local min_timer
  ---@type number|?
  local min_time_left

  for _, t in pairs(self.timers) do
    local time_left = t:time_remaining()
    if time_left ~= nil then
      if min_time_left == nil or time_left < min_time_left then
        min_timer = t
        min_time_left = time_left
      end
    end
  end

  return min_timer
end

---Get a list of all active timers.
---@return pomo.Timer[]
TimerStore.get_all = function(self)
  return vim.tbl_values(self.timers)
end

---Pop a timer from the store. If no ID is given, the latest timer is popped.
---@param timer_id integer|?
---@return pomo.Timer|?
TimerStore.pop = function(self, timer_id)
  if timer_id == nil then
    if self:len() == 1 then
      -- note that the `#` operator always returns the highest non-nil index in an array,
      -- not necessarily its length, which is why this works.
      return self:pop(#self.timers)
    else
      local latest_timer = self:get_latest()
      if latest_timer ~= nil then
        return self:pop(latest_timer.id)
      else
        return nil
      end
    end
  else
    local timer = self:get(timer_id)
    if timer ~= nil then
      self:remove(timer)
    end
    return timer
  end
end

---Save the current state of timers to a file.
function TimerStore:save_to_file()
  local file = io.open(filename, "w")
  if file then
    for _, timer in pairs(self.timers) do
      file:write(timer.store(timer) .. "\n")
    end
    file:close()
  else
    error("Could not open file for writing: " .. filename)
  end
end

function TimerStore:load_from_file()
  local Timer = require "pomo.timer"
  local file = io.open(filename, "r")
  if file then
    for line in file:lines() do
      local timer = Timer.load(line, config)
      if timer and timer.id then
        self.timers[timer.id] = timer
      else
        print("Failed to load timer from line: " .. line)
      end
    end
    file:close()
  else
    error("Could not open file for reading: " .. filename)
  end

  -- if self:len() > 0 then
  --   local first_timer = self:get_first_to_finish()
  --   if first_timer ~= nil then
  --     first_timer:resume()
  --   end
  -- end
end

---Update or add a timer in the saved file.
---@param timer pomo.Timer
function TimerStore:update_saved_timer(timer, delete)
  local Timer = require "pomo.timer"
  local timers = {}
  local file = io.open(filename, "r")
  print("Updating timer " .. timer.id .. " in file " .. filename .. " with delete: " .. tostring(delete))

  if file then
    print "Reading file"
    print "file content: "
    for line in file:lines() do
      print(line)
    end
    for line in file:lines() do
      print("Reading line: " .. line)
      local existing_timer = Timer.load(line, config)
      print("Loaded timer " .. existing_timer.id .. " from line: " .. line)
      if existing_timer and existing_timer.id then
        if delete and existing_timer.id == timer.id then
          print("Deleting timer " .. existing_timer.id)
        else
          timers[existing_timer.id] = existing_timer
        end
      end
    end
    file:close()
  end

  timers[timer.id] = timer

  file = io.open(filename, "w")
  if file then
    for _, t in pairs(timers) do
      file:write(t.store(t) .. "\n")
    end
    file:close()
  else
    error("Could not open file for writing: " .. filename)
  end
end
return TimerStore
