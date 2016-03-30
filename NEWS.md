# typecheck NEWS - User visible changes

## Noteworthy changes in release ?.? (????-??-??) [?]

### New features

  - Support type annotations with concat decorators.

    ```lua
    local my_function = argscheck "my_function (int, int) => int" ..
    function (a, b)
      return a + b
    end
    ```

  - New `check` method for ensuring that a single argument matches a
    given type specifier.

  - New "functor" type specifier for matching objects with a `__call`
    metamethod - note, most `std.object` derived types will match
    successfully against the "functor" specifier.

  - New "callable" type specifier for matching both objects with a
    `__call` metamethod, and objects for which Lua `type` returns
    "function" - not, this is exactly what the "function" specifier
    used to do.

### Incompatible changes

  - The "function" (and "func") type specifiers no longer match objects
    with a `__call` metamethod.  Use the new "callable" type specifier
    to match both types in the way that "function" used to, including
    most `std.object` derived types.


## Noteworthy changes in release 1.0 (2016-01-25) [stable]

### New features

  - Initial release, now separated out from lua-stdlib.
