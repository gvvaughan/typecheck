--[[
 Gradual Function Type Checking for Lua 5.1, 5.2, 5.3 & 5.4
 Copyright (C) 2014-2020 Gary V. Vaughan
]]

local _ENV = require 'typecheck._strict' {
   _G = _G,
   debug_getfenv = debug.getfenv or false,
   debug_getinfo = debug.getinfo,
   debug_getupvalue = debug.getupvalue,
   debug_setfenv = debug.setfenv or false,
   debug_setupvalue = debug.setupvalue,
   debug_upvaluejoin = debug.upvaluejoin,
   floor = math.floor,
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



--[[ ============== ]]--
--[[ Normalization. ]]--
--[[ ============== ]]--


local function getmetamethod(x, n)
   local m = (getmetatable(x) or {})[tostring(n)]
   if type(m) == 'function' then
      return m
   end
   if type((getmetatable(m) or {}).__call) == 'function' then
      return m
   end
end


local pack_mt = {
   __len = function(self)
      return self.n
   end,
}


local pack = pack or function(...)
   return {n=select('#', ...), ...}
end


local normalize_pack = function(...)
   return setmetatable(pack(...), pack_mt)
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



--[[ ================= ]]--
--[[ Public Interface. ]]--
--[[ ================= ]]--


return {
   --- Get a function or functor environment.
   -- @see std.normalize.getfenv
   getfenv = normalize_getfenv,

   --- Return named metamethod, if callable, otherwise `nil`.
   -- @see std.normalize.getmetamethod
   getmetamethod = getmetamethod,

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
