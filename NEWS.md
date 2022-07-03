# typecheck NEWS - User visible changes

## Noteworthy changes in release ?.? (????-??-??) [?]

### New Features

  - Support importing into another project directly with:

    ```sh
    $ cp ../typecheck/lib/typecheck/init.lua lib/typecheck.lua
    ```

### Bug fixes

  - No matter whether 'int' or 'integer' is specified, always use
    'integer' in error messages, for consistency with 'bool' as an
    alias of 'boolean'.

  - When 'table of int', 'list of funcs', 'table of bool' or
    similar are specified, consistently use 'table of integers',
    'list of functions', 'table of booleans', etc.

  - Correctly diagnose unexpected `nil` arguments with 'got nil',
    and missing arguments with 'got no value'.

  - Diagnose passing of incompatible objects with a `__tostring`
    metamethod to parameters that require a string instead of silently
    coercing to a string.

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

  - `argcheck`, `argerror`, `argscheck` and `resulterror` no longer
    accept a table with a `__tostring` metamethod as a substitute for
    an actual string for those parameters that require a string.


## Noteworthy changes in release 2,1 (2020-04-24) [stable]

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
