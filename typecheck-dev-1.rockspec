local _MODREV, _SPECREV = 'dev', '-1'

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
   homepage = 'https://gvvaughan.github.io/typecheck',
   issues_url = 'https://github.com/gvvaughan/typecheck/issues',
   license = 'MIT/X11',
}

source = {
   url = 'https://github.com/gvvaughan/typecheck/archive/v' .. _MODREV .. '.zip',
   dir = 'typecheck-' .. _MODREV,
}

dependencies = {
   'lua >= 5.1, < 5.6',
}

build_dependencies = {
   'luarocks-build-luke >= 0.2',
}

build = {
   type = 'luke',

   modules = {
      {['typecheck']         = 'lib/typecheck/init.lua'},
      {['typecheck._normalize'] = 'lib/typecheck/_normalize.lua'},
      {['typecheck.version'] = 'lib/typecheck/version.lua.in'},
   },

   -- A release commits its LDocs to install.
   copy_directories = {'doc'},
}

test_dependencies = {
   'ansicolors',
   'luacov',
   'specl >= 16',
}

test = {
   type = 'command',
   command = 'specl -vfreport --coverage spec/*_spec.yaml',
}

if _MODREV == 'dev' then
   -- luarocks.org's ldoc fails on Lua 5.5; gvvaughan's works.
   build_dependencies[#build_dependencies + 1] = 'gvvaughan/ldoc'

   -- Stamp a development build with who made it, and from which commit.
   build.version = '$USER/$gitref'

   build.copy_directories = nil

   source = {
      url = 'git+https://github.com/gvvaughan/typecheck.git',
   }
end
