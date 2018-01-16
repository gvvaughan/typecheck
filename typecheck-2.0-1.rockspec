--[[
 Gradual Function Type Checking for Lua 5.1, 5.2 & 5.3.
 Copyright (C) Gary V. Vaughan 2014-2018
]]

local _MODREV, _SPECREV = '2.0', '-1'

package = 'typecheck'
version = _MODREV .. _SPECREV

description = {
   summary = 'Gradual type checking for Lua functions.',
   detailed = [[
      A Luaish run-time gradual type checking system, for argument and
      return types at function boundaries with simple annotations that can
      be enabled or disabled for production code, with a Lua API modelled
      on the core Lua C language API.
   ]],
   homepage = 'http://gvvaughan.github.io/typecheck',
   license = 'MIT/X11',
}

dependencies = {
   'lua >= 5.1, < 5.4',
   'std.normalize >= 2.0.1',
}

source = (function(gitp)
   if gitp then
      dependencies[#dependencies + 1] = 'ldoc'

      return {
         url = 'git://github.com/gvvaughan/typecheck.git',
      }
   else
      return {
         url = 'http://github.com/gvvaughan/typecheck/archive/v' .. _MODREV .. '.zip',
         dir = 'typecheck-' .. _MODREV,
      }
   end
end)(_MODREV == 'git')

build = {
   type = 'builtin',
   modules = {
      ['typecheck']           = 'lib/typecheck/init.lua',
      ['typecheck.version']   = 'lib/typecheck/version.lua',
   },
}
