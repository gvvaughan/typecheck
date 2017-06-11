Gradual type checking for Lua functions
=======================================

Copyright (C) 2014-2017 [Gary V. Vaughan][github]

[![License](http://img.shields.io/:license-mit-blue.svg)](http://mit-license.org)
[![travis-ci status](https://secure.travis-ci.org/gvvaughan/typecheck.png?branch=master)](http://travis-ci.org/gvvaughan/typecheck/builds)
[![codecov.io](https://codecov.io/gh/gvvaughan/typecheck/branch/master/graph/badge.svg)](https://codecov.io/gh/gvvaughan/typecheck)
[![Stories in Ready](https://badge.waffle.io/gvvaughan/typecheck.png?label=ready&title=Ready)](https://waffle.io/gvvaughan/typecheck)

A Luaish run-time gradual type checking system, for argument and return
types at function boundaries with simple annotations that can be disabled
in production code.  Its API and type mismatch errors are modelled on the
core Lua C-language `argcheck ()` API.

- *Luaish*: Type check failures show error messages in the same format
  as Lua itself;
- *run time*: Without changing any library code, the application can
  decide at run time whether to enable type checking as it loads the
  library;
- *gradual*: Type checks can be introduced to the functions in your code
  gradually, to as few or as many as seem useful;
- *type checking*: function argument types and return types are checked
  against the specification, and raise an error if some don't match

This is a light-weight library for [Lua][] 5.1 (including [LuaJIT][]),
5.2 and 5.3 written in pure Lua.

[github]: http://github.com/gvvaughan/typecheck/ "Github repository"
[lua]: http://www.lua.org "The Lua Project"
[luajit]: http://luajit.org "The LuaJIT Project"


Installation
------------

The simplest and best way to install typecheck is with [LuaRocks][]. To
install the latest release (recommended):

```bash
    luarocks install typecheck
```

To install current git master (for testing, before submitting a bug
report for example):

```bash
    luarocks install http://raw.githubusercontent.com/gvvaughan/typecheck/master/typecheck-git-1.rockspec
```

The best way to install without [LuaRocks][] is to copy the entire
`lib/typecheck` directory into a subdirectory of your package search path.

[luarocks]: http://www.luarocks.org "Lua package manager"


Use
---

Add expressive type assertions on specific arguments right in the body
of a function, for cases where that function can only handle specific
types in that argument:

```lua
    local argcheck = require "typecheck".argcheck

    local function case (with, branches)
      argcheck ("std.functional.case", 2, "#table", branches)
      ...
```

Or more comprehensively, wrap exported functions to raise an error if
the return or argument types do not meet your specification:

```lua
    return {
      len = argscheck ("string.len (string) => int", string.len),
      ...
```

Alternatively, argscheck can be used as an annotation, which makes it
look nicer when used at declaration time:

```lua
    local my_function = argscheck "my_function (int, int) => int" ..
    function (a, b)
      return a + b
    end
```

By default, type checks are performed on every call.  But, they can be
turned off and all of the run-time overhead eliminated in production
code, either by setting the global `_DEBUG = false` prior to loading
`typecheck.lua` or, in conjunction with [lua-stdlib][]'s `debug_init`
module, setting `std.debug_init._DEBUG.argcheck` to `false` (for
compatibility with code that used `std.debug.argscheck` type checking
while it was still bundled with stdlib).

[lua-stdlib]: http://github.com/lua-stdlib/lua-stdlib "standard libraries"


Documentation
-------------

The latest release is [documented with LDoc][github.io].
Pre-built HTML files are included in the [release tarball][].

[github.io]: http://gvvaughan.github.io/typecheck
[release]: http://gvvaughan.github.io/typecheck/releases


Bug reports and code contributions
----------------------------------

Please make bug reports and suggestions as [GitHub Issues][issues].
Pull requests are especially appreciated.

But first, please check that your issue has not already been reported by
someone else, and that it is not already fixed by [master][github] in
preparation for the next release (see Installation section above for how
to temporarily install master with [LuaRocks][]).

There is no strict coding style, but please bear in mind the following
points when proposing changes:

0. Follow existing code. There are a lot of useful patterns and avoided
   traps there.

1. 2-character indentation using SPACES in Lua sources.

[issues]: http://github.com/gvvaughan/typecheck/issues
