# typecheck NEWS - User visible changes

## Noteworthy changes in release ?.? (????-??-??) [?]

### Incompatible changes

  - typecheck is built from the `build` table of its rockspec, by the
    `luarocks-build-luke` LuaRocks build backend, which LuaRocks
    installs for the build, so there is no `build-aux/luke` build to
    run, and no build without LuaRocks.  Building LDocs, which a release
    commits, no longer needs a build dependency of its own.

### Bug fixes

  - typecheck applies strict variable declarations to its own modules
    whenever std.strict is installed, as std.normalize does, and no
    longer only when std._debug is installed too.  Setting the `strict`
    hint of std._debug to false still turns them off.

  - A function that argscheck wraps no longer raises an error, instead
    of reporting a type error, for an argument whose `__metatable` field
    is not a table, such as `true`.

  - typecheck takes its `callable`, `getmetamethod`, `getfenv`,
    `setfenv` and other core functions from `typecheck._normalize`, a
    copy of the one file that std.normalize keeps them in, so they
    cannot differ from std.normalize's: its `getfenv` and `setfenv` no
    longer return a trailing `nil` on Lua 5.1.


## Noteworthy changes in release 4 (2026-10-20) [stable]

### New features

  - A parameter in angle brackets is optional, but can't be skipped:
    it may only be omitted along with every parameter after it, as
    Lua's own optional arguments are.  So with

    ```lua
    find = argscheck('find(string, string, <?int>, <?boolean|:plain>)', find)
    ```

    `find('a', 'b')` and `find('a', 'b', 1, true)` are accepted, but
    `find('a', 'b', false)` is diagnosed with 'integer or nil expected,
    got boolean'.  A parameter in square brackets can still be skipped,
    so `[?int], [?boolean|:plain]` accepts that `false` as the
    `:plain` argument.  A required parameter can't follow an angle
    bracketed one, and `argscheck` diagnoses a declaration with one.

### Incompatible changes

  - Type mismatch messages name a number argument 'number' again, as
    Lua itself does, rather than 'integer' or 'float', and a number or
    numeric string with a fractional part fails an 'int' check with
    'number has no integer representation', the message Lua uses for
    the same failure.
    The 'integer' and 'float' names that release 3.0 introduced
    weren't available on Lua 5.1, 5.2 or LuaJIT, which store every
    number as a C double, and so differed between Lua versions: `1.0`
    was an 'integer' on Lua 5.1 but a 'float' on Lua 5.3 and newer.

### Bug fixes

  - `argscheck` now checks an optional final argument against its own
    type.  Previously `argscheck('f(string, [int])', fn)` accepted
    `f('a', 'x')`, because the permutation without the optional
    parameter matched the surplus 'x' against its last type, `string`.


## Noteworthy changes in release 3.1 (2026-10-11) [stable]

### New features

  - `std._debug` is no longer a hard dependency.  Without it, runtime
    type checks are always enabled; install it to control them with
    `argcheck` hints as before.

### Incompatible changes

  - Strict global symbol checks for typecheck's own module environment
    now need both `std._debug` and `std.strict` installed, matching
    luaposix.  Previously `std.strict` alone was enough when `std._debug`
    was missing.

### Bug fixes

  - `argscheck` no longer overwrites the environment of the wrapped
    function with typecheck's own on every call, which broke functions
    defined in a module with a private `_ENV`.  Calling `setfenv` on
    the wrapper still propagates the new environment to the wrapped
    function.


## Noteworthy changes in release 3.0.1 (2026-07-27) [stable]

### New features

  - Initial support for Lua 5.5.


## Noteworthy changes in release 3.0 (2023-01-31) [stable]

### New Features

  - `ARGCHECK_FRAME` is now exported for use when writing your own
    functions that need to adjust any stack `level` argument they
    support, rather than having to divine if from the internals of
    `_debug.argcheck`.

  - Accept either of 'integer' or 'int' in an argcheck typespec.

  - When diagnosing a type mismatch, be specific about unexpected
    'integer' or 'float' rather than just 'number'

    ```
    bad argument #1 to 'getfenv' (integer expected, got float)
    ```

  - Instead of diagnosing an argument mismatch against `?any` as
    'expected any value or nil, got no value', we now get
    'expected argument, got no value'.  Similarly, for missing
    results for `?any' we now get 'expected result, go no value'.

  - Support importing into another project directly with:

    ```sh
    $ cp ../typecheck/lib/typecheck/init.lua lib/typecheck.lua
    ```

  - Multi-typed specifications are sorted asciibetically in error
    messages by `argerror` and `resulterror` to make writing tests
    for typechecked functions easier.

### Bug fixes

  - No matter whether 'int' or 'integer' is specified, always use
    'integer' in error messages, for consistency with 'bool' as an
    alias of 'boolean'.

  - When 'table of int', 'list of funcs', 'table of bool' or
    similar are specified, consistently use 'table of integers',
    'list of functions', 'table of booleans', etc.

  - `argscheck` now correctly diagnoses unexpected `nil` arguments
    with 'got nil', and missing arguments with 'got no value'.
    Likewise for result errors about unexpected `nil` results and
    missing return values.

  - Diagnose passing of incompatible objects with a `__tostring`
    metamethod to parameters that require a string instead of silently
    coercing to a string.

  - Functable's are most definitely NOT functors as that term is used
    by functional programmers.  The library will accept 'functor'
    as a synonym for backwards compatibility, but otherwise we now
    use the term functable everywhere to avoid confusion.

### Incompatible changes

  - `types.stringy` is no longer available; silently converting any
    object passed to a string parameter by calling the `__tostring`
    metamethod has unintended consequences for the function behaviour
    and behaves differently when typechecking is disabled and the
    conversion to string is consequently disabled.

    1. If you know you want an argument converted to a string before
       passing to typechecked function, you should call `tostring` on
       it at the call-site.
    2. If you know you want tables with `__tostring` metamethods to
       be valid arguments, make the typespec 'string|table' and call
       `tostring` on it in your function.

  - Number-like string arguments are considered a mismatch for
    previously compatible expected number types for the same reason.
    As above, either call `tonumber` at the call-site, or make the
    typespec 'number|string' and call `tonumber` inside your function.

  - `argcheck`, `argerror`, `argscheck` and `resulterror` no longer
    accept a table with a `__tostring` metamethod as a substitute for
    an actual string for those parameters that require a string.

  - `extramsg_mismatch` provides more specific details when the
    expected argument is 'int' or 'integer':

    ```
    bad argument #1 to 'getfenv' (float has no integer representation)
    ```


## Noteworthy changes in release 2.1 (2020-04-24) [stable]

### New features

  - Initial support for Lua 5.4.

  - No longer depends on `std.normalize`.

  - No need to preinstall `std.strict` for deployment, of course that
    means without runtime global variable checking.  In development
    environments, `std.strict` will be loaded and used for runtime
    checks as before.

### Bug fixes

  - works with std.strict again.


## Noteworthy changes in release 2.0 (2018-01-15) [stable]

### Incompatible changes

  - Use `std._debug` hints to enable or disable runtime type
    checking instead of shared global `_DEBUG` symbol.


## Noteworthy changes in release 1.1 (2017-07-07) [stable]

### New features

  - Support type annotations with concat decorators.

    ```lua
    local my_function = argscheck "my_function (int, int) => int" ..
    function (a, b)
      return a + b
    end
    ```

  - New `check` method for ensuring that a single value matches a
    given type specifier.

  - New "functor" type specifier for matching objects with a `__call`
    metamethod - note, most `std.object` derived types will match
    successfully against the "functor" specifier.

  - New "callable" type specifier for matching both objects with a
    `__call` metamethod, and objects for which Lua `type` returns
    "function" - note, this is exactly what the "function" specifier
    used to do.

### Bug fixes

  - `argerror` and `resulterror` pass level 0 argument through to
    `error` to suppress file and line number prefix to error message.

### Incompatible changes

  - The "function" (and "func") type specifiers no longer match objects
    with a `__call` metamethod.  Use the new "callable" type specifier
    to match both types in the way that "function" used to, including
    most `std.object` derived types.

  - Rather than a hardcoded `typecheck._VERSION` string, install a
    generated `typecheck.version` module, and autoload it on reference.


## Noteworthy changes in release 1.0 (2016-01-25) [stable]

### New features

  - Initial release, now separated out from lua-stdlib.
