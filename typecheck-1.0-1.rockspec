package = "typecheck"
version = "1.0-1"

description = {
  summary = "Gradual function call type checking",
  detailed = [[
    A Luaish run-time gradual type checking system, for argument and
    return types at function boundaries with simple annotations that can
    be enabled or disabled for production code, with a Lua API modelled
    on the core Lua C language API.
  ]],
  homepage = "http://gvvaughan.github.io/typecheck",
  license = "MIT/X11",
}

source = {
  url = "git://github.com/gvvaughan/typecheck.git",
}

dependencies = {
  "lua >= 5.1, < 5.4",
}

build = {
  type = "builtin",
  modules = {
    typecheck = "typecheck.lua",
  },
}
