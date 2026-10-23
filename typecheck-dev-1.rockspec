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

build = {
   type = 'command',
   build_command = '$(LUA) build-aux/luke'
      .. ' package="' .. package .. '"'
      .. ' version="' .. _MODREV .. '"'
      .. ' PREFIX="$(PREFIX)"'
      .. ' LUA="$(LUA)"'
      ,
   install_command = '$(LUA) build-aux/luke install --quiet'
      .. ' INST_LUADIR="$(LUADIR)"'
      ,
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
   build_dependencies = {'gvvaughan/ldoc'}

   build.copy_directories = nil

   source = {
      url = 'git+https://github.com/gvvaughan/typecheck.git',
   }
else
   -- A release commits its LDocs, so don't build them again.
   build.build_command = build.build_command .. ' LDOC=true'
end
