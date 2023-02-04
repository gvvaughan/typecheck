local _MODREV, _SPECREV = 'git', '-1'

package = 'typecheck'
version = _MODREV .. _SPECREV

rockspec_format = '3.0'

description = {
   summary = 'Gradual type checking for Lua functions.',
   detailed = [[
      A Luaish run-time gradual type checking system, for argument and
      return types at function boundaries with simple annotations that can
      be enabled or disabled for production code, with a Lua API modelled
      on the core Lua C language API.
   ]],
   homepage = 'http://gvvaughan.github.io/typecheck',
   issues_url = 'https://github.com/gvvaughan/typecheck/issues',
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

build_dependencies = {
   'ldoc',
}

build = {
   modules = {
      ['typecheck']            = 'lib/typecheck/init.lua',
      ['typecheck.version']    = 'lib/typecheck/version.lua',
   },
   copy_directories = {'doc'},
}

test_dependencies = {
   'ansicolors',
   'luacov',
   'specl',
}

test = {
   type = 'command',
   command = 'make check',
}

if _MODREV == 'git' then
   source = {
      url = 'git://github.com/gvvaughan/typecheck.git',
   }
end
