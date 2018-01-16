# typecheck NEWS - User visible changes

## Noteworthy changes in release ?.? (????-??-??) [?]



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
