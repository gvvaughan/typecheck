--[[
 Gradual Function Type Checking for Lua 5.1, 5.2, 5.3 & 5.4
 Copyright (C) 2014-2018 Gary V. Vaughan
]]

local _ENV = require 'typecheck._strict' {
   _G = _G,
   _debug = require 'std._debug',
   concat = table.concat,
   debug_getfenv = debug.getfenv or false,
   debug_getinfo = debug.getinfo,
   debug_getupvalue = debug.getupvalue,
   debug_setfenv = debug.setfenv or false,
   debug_setupvalue = debug.setupvalue,
   debug_upvaluejoin = debug.upvaluejoin,
   error = error,
   floor = math.floor,
   format = string.format,
   getfenv = getfenv or false,
   getmetatable = getmetatable,
   pack = table.pack or false,
   select = select,
   setfenv = setfenv or false,
   setmetatable = setmetatable,
   tointeger = math.tointeger or false,
   tostring = tostring,
   type = type,
   unpack = table.unpack or unpack,
}

-- There's an additional stack frame to count over from inside functions
-- with argchecks enabled.
local ARGCHECK_FRAME = 0



--[[ =============== ]]--
--[[ Normalizeation. ]]--
--[[ =============== ]]--


local function getmetamethod(x, n)
   local m = (getmetatable(x) or {})[tostring(n)]
   if type(m) == 'function' then
      return m
   end
   if type((getmetatable(m) or {}).__call) == 'function' then
      return m
   end
end


local function iscallable(x)
   return type(x) == 'function' or getmetamethod(x, '__call')
end


local pack_mt = {
   __len = function(self)
      return self.n
   end,
}


local normalize_pack = pack or function(...)
   return {n=select('#', ...), ...}
end


local function rawlen(x)
   -- Lua 5.1 does not implement rawlen, and while # operator ignores
   -- __len metamethod, `nil` in sequence is handled inconsistently.
   if type(x) ~= 'table' then
      return #x
   end

   local n = #x
   for i = 1, n do
      if x[i] == nil then
         return i -1
      end
   end
   return n
end


local function len(x)
   local m = getmetamethod(x, '__len')
   if m then
      return m(x)
   elseif getmetamethod(x, '__tostring') then
      x = tostring(x)
   end
   return rawlen(x)
end


local normalize_tointeger = (function(f)
   if not f then
      -- No host tointeger implementation, use our own.
      return function(x)
        if type(x) == 'number' and x - floor(x) == 0.0 then
           return x
        end
      end

   elseif f '1' ~= nil then
      -- Don't perform implicit string-to-number conversion!
      return function(x)
         if type(x) == 'number' then
            return tointeger(x)
         end
      end
   end

   -- Host tointeger is good!
   return f
end)(tointeger)


local normalize_getfenv
if debug_getfenv then

   normalize_getfenv = function(fn)
      local n = normalize_tointeger(fn or 1)
      if n then
         if n > 0 then
            -- Adjust for this function's stack frame, if fn is non-zero.
            n = n + 1
         end

         -- Return an additional nil result to defeat tail call elimination
         -- which would remove a stack frame and break numeric *fn* count.
         return getfenv(n), nil
      end

      if type(fn) ~= 'function' then
         -- Unwrap functors:
         -- No need to recurse because Lua doesn't support nested functors.
         -- __call can only (sensibly) be a function, so no need to adjust
         -- stack frame offset either.
         fn =(getmetatable(fn) or {}).__call or fn
      end

      -- In Lua 5.1, only debug.getfenv works on C functions; but it
      -- does not work on stack counts.
      return debug_getfenv(fn)
   end

else

   -- Thanks to http://lua-users.org/lists/lua-l/2010-06/msg00313.html
   normalize_getfenv = function(fn)
      if fn == 0 then
         return _G
      end
      local n = normalize_tointeger(fn or 1)
      if n then
         fn = debug_getinfo(n + 1, 'f').func
      elseif type(fn) ~= 'function' then
         fn = (getmetatable(fn) or {}).__call or fn
      end

      local name, env
      local up = 0
      repeat
         up = up + 1
         name, env = debug_getupvalue(fn, up)
      until name == '_ENV' or name == nil
      return env
   end

end


local normalize_setfenv
if debug_setfenv then

   normalize_setfenv = function(fn, env)
      local n = normalize_tointeger(fn or 1)
      if n then
         if n > 0 then
            n = n + 1
         end
         return setfenv(n, env), nil
      end
      if type(fn) ~= 'function' then
         fn =(getmetatable(fn) or {}).__call or fn
      end
      return debug_setfenv(fn, env)
   end

else

   -- Thanks to http://lua-users.org/lists/lua-l/2010-06/msg00313.html
   normalize_setfenv = function(fn, env)
      local n = normalize_tointeger(fn or 1)
      if n then
         if n > 0 then
            n = n + 1
         end
         fn = debug_getinfo(n, 'f').func
      elseif type(fn) ~= 'function' then
         fn =(getmetatable(fn) or {}).__call or fn
      end

      local up, name = 0
      repeat
         up = up + 1
         name = debug_getupvalue(fn, up)
      until name == '_ENV' or name == nil
      if name then
         debug_upvaluejoin(fn, up, function() return name end, 1)
         debug_setupvalue(fn, up, env)
      end
      return n ~= 0 and fn or nil
   end

end


local function normalize_unpack(t, i, j)
   return unpack(t, normalize_tointeger(i) or 1, normalize_tointeger(j) or len(t))
end



--[[ =============== ]]--
--[[ Implementation. ]]--
--[[ =============== ]]--


local function argerror(name, i, extramsg, level)
   level = normalize_tointeger(level) or 1
   local s = format("bad argument #%d to '%s'", normalize_tointeger(i), name)
   if extramsg ~= nil then
      s = s .. ' (' .. extramsg .. ')'
   end
   error(s, level > 0 and level + 2 + ARGCHECK_FRAME or 0)
end


local argscheck
do
   -- Set argscheck according to whether argcheck was required by _debug.
   if _debug.argcheck then

      ARGCHECK_FRAME = 1

      local function icalls(name, checks, argu)
         return function(state, i)
            if i < state.checks.n then
               i = i + 1
               local r = normalize_pack(state.checks[i](state.argu, i))
               if r.n > 0 then
                  return i, r[1], r[2]
               end
               return i
            end
         end, {argu=argu, checks=checks}, 0
      end

      argscheck = function(name, ...)
         return setmetatable(normalize_pack(...), {
            __concat = function(checks, inner)
               if not iscallable(inner) then
                  error("attempt to annotate non-callable value with 'argscheck'", 2)
               end
               return function(...)
                  local argu = normalize_pack(...)
                  for i, expected, got in icalls(name, checks, argu) do
                     if got or expected then
                        local buf, extramsg = {}
                        if expected then
                           got = got or 'got ' .. type(argu[i])
                           buf[#buf +1] = expected .. ' expected, ' .. got
                        elseif got then
                           buf[#buf +1] = got
                        end
                        if #buf > 0 then
                           extramsg = concat(buf)
                        end
                        return argerror(name, i, extramsg, 3), nil
                     end
                  end
                  -- Tail call pessimisation: inner might be counting frames,
                  -- and have several return values that need preserving.
                  -- Different Lua implementations tail call under differing
                  -- conditions, so we need this hair to make sure we always
                  -- get the same number of stack frames interposed.
                  local results = normalize_pack(inner(...))
                  return normalize_unpack(results, 1, results.n)
               end
            end,
         })
      end

   else

      -- Return `inner` untouched, for no runtime overhead!
      argscheck = function(...)
         return setmetatable({}, {
            __concat = function(_, inner)
               return inner
            end,
         })
      end

   end
end



--[[ ================= ]]--
--[[ Public Interface. ]]--
--[[ ================= ]]--


return {
   --- Raise a bad argument error.
   -- @see typecheck.argerror
   argerror = argerror,

   --- A rudimentary argument type validation decorator.
   --
   -- Return the checked function directly if `_debug.argcheck` is reset,
   -- otherwise use check function arguments using predicate functions in
   -- the corresponding position in the decorator call.
   -- @function argscheck
   -- @string name function name to use in error messages
   -- @tparam funct predicate return true if checked function argument is
   --    valid, otherwise return nil and an error message suitable for
   --    *extramsg* argument of @{argerror}
   -- @tparam func ... additional predicates for subsequent checked
   --    function arguments
   -- @raises argerror when an argument validator returns failure
   -- @see argerror
   -- @usage
   --    local unpack = argscheck('unpack', types.table) ..
   --    function(t, i, j)
   --       return table.unpack(t, i or 1, j or #t)
   --    end
   argscheck = argscheck,

   --- Get a function or functor environment.
   -- @see std.normalize.getfenv
   getfenv = normalize_getfenv,

   --- Return named metamethod, if callable, otherwise `nil`.
   -- @see std.normalize.getmetamethod
   getmetamethod = getmetamethod,

   --- Predicate to check for a function or table with a `__call`
   -- metamethod.
   -- @function iscallable
   -- @param x argument to be typechecked
   -- @treturn boolean `true` if *x* can be called like a function
   -- @see typecheck.types.callable
   iscallable = iscallable,

   --- Deterministic, functional version of core Lua `#` operator.
   -- @see std.normalize.len
   len = len,

   --- Return a list of given arguments, with field `n` set to the
   -- length.
   -- @see std.normalize.pack
   pack = normalize_pack,

   --- Length of a string or table object without using any metamethod.
   -- @see std.normalize.rawlen
   rawlen = rawlen,

   --- Raise a bad result error.
   -- @see typecheck.resulterror
   resulterror = function(name, i, extramsg, level)
      level = level or 1
      local s = format("bad result #%d from '%s'", i, name)
      if extramsg ~= nil then
         s = s .. ' (' .. extramsg .. ')'
      end
      error(s, level > 0 and level + 1 + ARGCHECK_FRAME or 0)
   end,

   --- Set a function or functor environment.
   -- @see std.normalize.setfenv
   setfenv = normalize_setfenv,

   --- Convert to an integer and return if possible, otherwise `nil`.
   -- @see std.normalize.math.tointeger
   tointeger = normalize_tointeger,

   --- Either `table.unpack` in newer-, or `unpack` in older-Lua implementations.
   -- @see std.normalize.unpack
   unpack = normalize_unpack,
}
