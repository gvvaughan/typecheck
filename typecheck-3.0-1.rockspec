local _MODREV, _SPECREV = '3.0', '-1'

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

source = {
   url = 'http://github.com/gvvaughan/typecheck/archive/v' .. _MODREV .. '.zip',
   dir = 'typecheck-' .. _MODREV,
}

dependencies = {
   'lua >= 5.1, < 5.5',
   'std._debug >= 1.0.1',
}

build = {
   type = 'builtin',
   modules = {
      ['typecheck']            = 'lib/typecheck/init.lua',
      ['typecheck.version']    = 'lib/typecheck/version.lua',
   },
   copy_directories = {'doc'},
}

if _MODREV == 'git' then
   build.copy_directories = nil

   source = {
      url = 'git://github.com/gvvaughan/typecheck.git',
   }
end
