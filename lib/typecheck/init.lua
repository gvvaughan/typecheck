--[[
 Gradual Function Type Checking for Lua 5.1, 5.2 & 5.3
 Copyright(C) 2014-2018 Gary V. Vaughan
]]
--[[--
 Gradual type checking for Lua functions.

 The behaviour of the functions in this module are controlled by the value
 of the `argcheck` field maintained by the `std._debug` module.  Not setting
 a value prior to loading this module is equivalent to having `argcheck = true`.

 The first line of Lua code in production quality applications that value
 execution speed over rigorous function type checking should be:

    require 'std._debug' (false)

 Alternatively, if your project also depends on other `std._debug` hints
 remaining enabled:

    require 'std._debug'.argcheck = false

 This mitigates almost all of the overhead of type checking with the
 functions from this module.

 @module typecheck
]]


local _ENV = require 'std.normalize' {
   'math.floor',
   'std._debug',
   'std.normalize._typecheck',
   'string.find',
   'string.format',
   'string.gsub',
   'string.match',
   'string.sub',
   'table.concat',
   'table.insert',
   'table.remove',
   'table.sort',

   io_type = 'io.type',
}


local ARGCHECK_FRAME = _typecheck.ARGCHECK_FRAME



--[[ ================= ]]--
--[[ Helper Functions. ]]--
--[[ ================= ]]--


local function copy(dest, src)
   if src == nil then
      dest, src = {}, dest
   end
   for k, v in pairs(src) do
      dest[k] = v
   end
   return dest
end


local function split(s, sep)
   local r, patt = {}
   if sep == '' then
      patt = '(.)'
      r[#r + 1] = ''
   else
      patt = '(.-)' ..(sep or '%s+')
   end
   local b, slen = 0, len(s)
   while b <= slen do
      local e, n, m = find(s, patt, b + 1)
      r[#r + 1] = m or sub(s, b + 1, slen)
      b = n   or slen + 1
   end
   return r
end



--[[ =============================== ]]--
--[[ Implementation of value checks. ]]--
--[[ =============================== ]]--


--- Concatenate a table of strings using ', ' and ' or ' delimiters.
-- @tparam table alternatives a table of strings
-- @treturn string string of elements from alternatives delimited by ', '
--    and ' or '
local function orconcat(alternatives)
   if len(alternatives) > 1 then
      local t = copy(alternatives)
      local top = remove(t)
      t[#t] = t[#t] .. ' or ' .. top
      alternatives = t
   end
   return concat(alternatives, ', ')
end


local function _type(x)
   return (getmetatable(x) or {})._type or io_type(x) or type(x)
end


local function extramsg_gsub(match, replace)
   return function(s)
      return (gsub(s, match, replace))
   end
end


local EXTRAMSG_XFORMS = {
   extramsg_gsub('#table', 'non-empty table'),
   extramsg_gsub('#list', 'non-empty list'),
   extramsg_gsub('(%S+ of [^,%s]-)s? ', '%1s '),
   extramsg_gsub('(%S+ of [^,%s]-)s?,', '%1s,'),
   extramsg_gsub('(s, [^,%s]-)s? ', '%1s '),
   extramsg_gsub('(s, [^,%s]-)s?,', '%1s,'),
   extramsg_gsub('(of .-)s? or ([^,%s]-)s? ', '%1s or %2s '),
}


local function extramsg_mismatch(expectedtypes, actual, index)
   local actualtype = _type(actual) or type(actual)

   -- Tidy up actual type for display.
   if actualtype == 'nil' then
      actualtype = 'no value'
   elseif actualtype == 'string' and sub(actual, 1, 1) == ':' then
      actualtype = actual
   elseif type(actual) == 'table' then
      if actualtype == 'table' and (getmetatable(actual) or {}).__call ~= nil then
         actualtype = 'functor'
      elseif next(actual) == nil then
         local matchstr = ',' .. concat(expectedtypes, ',') .. ','
         if actualtype == 'table' and matchstr == ',#list,' then
            actualtype = 'empty list'
         elseif actualtype == 'table' or match(matchstr, ',#') then
            actualtype = 'empty ' .. actualtype
         end
      end
   end

   if index then
      actualtype = actualtype .. ' at index ' .. tostring(index)
   end

   -- Tidy up expected types for display.
   local expectedstr = expectedtypes
   if type(expectedtypes) == 'table' then
      local t = {}
      for i, v in ipairs(expectedtypes) do
         if v == 'func' then
            t[i] = 'function'
         elseif v == 'bool' then
            t[i] = 'boolean'
         elseif v == 'any' then
            t[i] = 'any value'
         elseif v == 'file' then
            t[i] = 'FILE*'
         elseif not index then
            t[i] = match(v, '(%S+) of %S+') or v
         else
            t[i] = v
         end
      end
      expectedstr = orconcat(t) .. ' expected'
      for _, fn in ipairs(EXTRAMSG_XFORMS) do
         expectedstr = fn(expectedstr)
      end
   end

   return expectedstr .. ', got ' .. actualtype
end


--- Compare *check* against type of *actual*. *check* must be a single type
-- @string check extended type name expected
-- @param actual object being typechecked
-- @treturn boolean `true` if *actual* is of type *check*, otherwise
--    `false`
local function checktype(check, actual)
   if check == 'any' and actual ~= nil then
      return true
   elseif check == 'file' and io_type(actual) == 'file' then
      return true
   elseif check == 'functor' or check == 'callable' then
      if(getmetatable(actual) or {}).__call ~= nil then
         return true
      end
   end

   local actualtype = type(actual)
   if check == actualtype then
      return true
   elseif check == 'bool' and actualtype == 'boolean' then
      return true
   elseif check == '#table' then
      if actualtype == 'table' and next(actual) then
         return true
      end
   elseif check == 'func' or check == 'callable' then
      if actualtype == 'function' then
         return true
      end
   elseif check == 'int' then
      if actualtype == 'number' and actual == floor(actual) then
         return true
      end
   elseif type(check) == 'string' and sub(check, 1, 1) == ':' then
      if check == actual then
         return true
      end
   end

   actualtype = _type(actual)
   if check == actualtype then
      return true
   elseif check == 'list' or check == '#list' then
      if actualtype == 'table' or actualtype == 'List' then
         local len, count = len(actual), 0
         local i = next(actual)
         repeat
            if i ~= nil then
               count = count + 1
            end
            i = next(actual, i)
         until i == nil or count > len
         if count == len and (check == 'list' or count > 0) then
            return true
         end
      end
   elseif check == 'object' then
      if actualtype ~= 'table' and type(actual) == 'table' then
         return true
      end
   end

   return false
end


local function typesplit(types)
   if type(types) == 'string' then
      types = split(gsub(types, '%s+or%s+', '|'), '%s*|%s*')
   end
   local r, seen, add_nil = {}, {}, false
   for _, v in ipairs(types) do
      local m = match(v, '^%?(.+)$')
      if m then
         add_nil, v = true, m
      end
      if not seen[v] then
         r[#r + 1] = v
         seen[v] = true
      end
   end
   if add_nil then
      r[#r + 1] = 'nil'
   end
   return r
end


local function checktypespec(expected, actual)
   expected = typesplit(expected)

   -- Check actual has one of the types from expected
   for _, expect in ipairs(expected) do
      local check, contents = match(expect, '^(%S+) of (%S-)s?$')
      check = check or expect

      -- Does the type of actual check out?
      ok = checktype(check, actual)

      -- For 'table of things', check all elements are a thing too.
      if ok and contents and type(actual) == 'table' then
         for k, v in pairs(actual) do
            if not checktype(contents, v) then
               return nil, extramsg_mismatch(expected, v, k)
            end
         end
      end
      if ok then
         return true
      end
   end

   return nil, extramsg_mismatch(expected, actual)
end



--[[ ================================== ]]--
--[[ Implementation of function checks. ]]--
--[[ ================================== ]]--


local function resulterror(name, i, extramsg, level)
   level = level or 1
   local s = format("bad result #%d from '%s'", i, name)
   if extramsg ~= nil then
      s = s .. ' (' .. extramsg .. ')'
   end
   error(s, level > 0 and level + 1 + ARGCHECK_FRAME or 0)
end


local function extramsg_toomany(bad, expected, actual)
   local s = 'no more than %d %s%s expected, got %d'
   return format(s, expected, bad, expected == 1 and '' or 's', actual)
end


--- Strip trailing ellipsis from final argument if any, storing maximum
-- number of values that can be matched directly in `t.maxvalues`.
-- @tparam table t table to act on
-- @string v element added to *t*, to match against ... suffix
-- @treturn table *t* with ellipsis stripped and maxvalues field set
local function markdots(t, v)
   return (gsub(v, '%.%.%.$', function()
      t.dots = true return ''
   end))
end


--- Calculate permutations of type lists with and without [optionals].
-- @tparam table t a list of expected types by argument position
-- @treturn table set of possible type lists
local function permute(t)
   if t[#t] then
      t[#t] = gsub(t[#t], '%]%.%.%.$', '...]')
   end

   local p = {{}}
   for i, v in ipairs(t) do
      local optional = match(v, '%[(.+)%]')

      if optional == nil then
         -- Append non-optional type-spec to each permutation.
         for b = 1, #p do
            insert(p[b], markdots(p[b], v))
         end
      else
         -- Duplicate all existing permutations, and add optional type-spec
         -- to the unduplicated permutations.
         local o = #p
         for b = 1, o do
            p[b + o] = copy(p[b])
            insert(p[b], markdots(p[b], optional))
         end
      end
   end
   return p
end


local function projectuniq(fkey, tt)
   -- project
   local t = {}
   for _, u in ipairs(tt) do
      t[#t + 1] = u[fkey]
   end

   -- split and remove duplicates
   local r, s = {}, {}
   for _, e in ipairs(t) do
      for _, v in ipairs(typesplit(e)) do
         if s[v] == nil then
            r[#r + 1], s[v] = v, true
         end
      end
   end
   return r
end


local function parsetypes(types)
   local r, permutations = {}, permute(types)
   for i = 1, #permutations[1] do
      r[i] = projectuniq(i, permutations)
   end
   r.dots = permutations[1].dots
   return r
end



local argcheck, argscheck   -- forward declarations

if _debug.argcheck then

   --- Return index of the first mismatch between types and values, or `nil`.
   -- @tparam table typelist a list of expected types
   -- @tparam table valuelist a table of arguments to compare
   -- @treturn int|nil position of first mismatch in *typelist*
   local function typematch(typelist, valuelist)
      local n = #typelist
      for i = 1, n do   -- normal parameters
         local ok = pcall(argcheck, 'pcall', i, typelist[i], valuelist[i])
         if not ok then
            return i
         end
      end
      for i = n + 1, valuelist.n do -- additional values against final type
         local ok = pcall(argcheck, 'pcall', i, typelist[n], valuelist[i])
         if not ok then
            return i
         end
      end
   end


   local function empty(t)
      return not next(t)
   end

   -- Pattern to normalize: [types...] to [types]...
   local last_pat = '^%[([^%]%.]+)%]?(%.*)%]?'

   --- Diagnose mismatches between *valuelist* and type *permutations*.
   -- @tparam table valuelist list of actual values to be checked
   -- @tparam table argt table of precalculated values and handler functiens
   local function diagnose(valuelist, argt)
      local permutations = argt.permutations

      local bestmismatch, t = 0
      for i, typelist in ipairs(permutations) do
         local mismatch = typematch(typelist, valuelist)
         if mismatch == nil then
            bestmismatch, t = nil, nil
            break -- every *valuelist* matched types from this *typelist*
         elseif mismatch > bestmismatch then
            bestmismatch, t = mismatch, permutations[i]
         end
      end

      if bestmismatch ~= nil then
         -- Report an error for all possible types at bestmismatch index.
         local i, expected = bestmismatch
         if t.dots and i > #t then
            expected = typesplit(t[#t])
         else
            expected = projectuniq(i, permutations)
         end

         -- This relies on the `permute()` algorithm leaving the longest
         -- possible permutation(with dots if necessary) at permutations[1].
         local typelist = permutations[1]

         -- For 'container of things', check all elements are a thing too.
         if typelist[i] then
            local check, contents = match(typelist[i], '^(%S+) of (%S-)s?$')
            if contents and type(valuelist[i]) == 'table' then
               for k, v in pairs(valuelist[i]) do
                  if not checktype(contents, v) then
                     argt.badtype(i, extramsg_mismatch(expected, v, k), 3)
                  end
               end
            end
         end

         -- Otherwise the argument type itself was mismatched.
         if t.dots or #t >= valuelist.n then
            argt.badtype(i, extramsg_mismatch(expected, valuelist[i]), 3)
         end
      end

      local n, t = valuelist.n, t or permutations[1]
      if t and t.dots == nil and n > #t then
         argt.badtype(#t + 1, extramsg_toomany(argt.bad, #t, n), 3)
      end
   end


   function argcheck(name, i, expected, actual, level)
      level = level or 1

      local ok, err = checktypespec(expected, actual)
      if err then
         argerror(name, i, err, level + 1)
      end
   end


   -- Pattern to extract: fname([types]?[, types]*)
   local args_pat = '^%s*([%w_][%.%:%d%w_]*)%s*%(%s*(.*)%s*%)'

   function argscheck(decl, inner)
      -- Parse 'fname(argtype, argtype, argtype...)'.
      local fname, argtypes = match(decl, args_pat)
      if argtypes == '' then
         argtypes = {}
      elseif argtypes then
         argtypes = split(argtypes, '%s*,%s*')
      else
         fname = match(decl, '^%s*([%w_][%.%:%d%w_]*)')
      end

      -- Precalculate vtables once to make multiple calls faster.
      local input, output = {
         bad = 'argument',
         badtype = function(i, extramsg, level)
            level = level or 1
            argerror(fname, i, extramsg, level + 1)
         end,
         permutations = permute(argtypes),
      }

      -- Parse '... => returntype, returntype, returntype...'.
      local returntypes = match(decl, '=>%s*(.+)%s*$')
      if returntypes then
         local i, permutations = 0, {}
         for _, group in ipairs(split(returntypes, '%s+or%s+')) do
            returntypes = split(group, ',%s*')
            for _, t in ipairs(permute(returntypes)) do
               i = i + 1
               permutations[i] = t
            end
         end

         -- Ensure the longest permutation is first in the list.
         sort(permutations, function(a, b)
            return #a > #b
         end)

         output = {
            bad = 'result',
            badtype = function(i, extramsg, level)
               level = level or 1
               resulterror(fname, i, extramsg, level + 1)
            end,
            permutations = permutations,
         }
      end

      local wrap_function = function(my_inner)
         return function(...)
            local argt = pack(...)

            -- Don't check type of self if fname has a ':' in it.
            if find(fname, ':') then
               remove(argt, 1)
               argt.n = argt.n - 1
            end

            -- Diagnose bad inputs.
            diagnose(argt, input)

            -- Propagate outer environment to inner function.
            if type(my_inner) == 'table' then
               setfenv((getmetatable(my_inner) or {}).__call, getfenv(1))
            else
               setfenv(my_inner, getfenv(1))
            end

            -- Execute.
            local results = pack(my_inner(...))

            -- Diagnose bad outputs.
            if returntypes then
               diagnose(results, output)
            end

            return unpack(results, 1, results.n)
         end
      end

      if inner then
         return wrap_function(inner)
      else
         return setmetatable({}, {
            __concat = function(_, concat_inner)
               return wrap_function(concat_inner)
            end
         })
      end
   end

else

   -- Turn off argument checking if _debug is false, or a table containing
   -- a false valued `argcheck` field.

   argcheck = function(...)
      return ...
   end
   argscheck = function(decl, inner)
      if inner then
         return inner
      else
         return setmetatable({}, {
            __concat = function(_, concat_inner)
               return concat_inner
            end
         })
      end
   end

end


local T, any, opt = _typecheck.types, _typecheck.any, _typecheck.opt

return setmetatable({
   --- Check the type of an argument against expected types.
   -- Equivalent to luaL_argcheck in the Lua C API.
   --
   -- Call `argerror` if there is a type mismatch.
   --
   -- Argument `actual` must match one of the types from in `expected`, each
   -- of which can be the name of a primitive Lua type, a stdlib object type,
   -- or one of the special options below:
   --
   --    #table    accept any non-empty table
   --    any       accept any non-nil argument type
   --    callable  accept a function or a functor
   --    file      accept an open file object
   --    func      accept a function
   --    function  accept a function
   --    functor   accept an object with a __call metamethod
   --    int       accept an integer valued number
   --    list      accept a table where all keys are a contiguous 1-based integer range
   --    #list     accept any non-empty list
   --    object    accept any std.Object derived type
   --    :foo      accept only the exact string ':foo', works for any :-prefixed string
   --
   -- The `:foo` format allows for type-checking of self-documenting
   -- boolean-like constant string parameters predicated on `nil` versus
   -- `:option` instead of `false` versus `true`.   Or you could support
   -- both:
   --
   --    argcheck('table.copy', 2, 'boolean|:nometa|nil', nometa)
   --
   -- A very common pattern is to have a list of possible types including
   -- 'nil' when the argument is optional.   Rather than writing long-hand
   -- as above, prepend a question mark to the list of types and omit the
   -- explicit 'nil' entry:
   --
   --     argcheck('table.copy', 2, '?boolean|:nometa', predicate)
   --
   -- Normally, you should not need to use the `level` parameter, as the
   -- default is to blame the caller of the function using `argcheck` in
   -- error messages; which is almost certainly what you want.
   -- @function argcheck
   -- @string name function to blame in error message
   -- @int i argument number to blame in error message
   -- @string expected specification for acceptable argument types
   -- @param actual argument passed
   -- @int[opt=2] level call stack level to blame for the error
   -- @usage
   --    local function case(with, branches)
   --       argcheck('std.functional.case', 2, '#table', branches)
   --       ...
   argcheck = argcheck,

   --- Raise a bad argument error.
   -- Equivalent to luaL_argerror in the Lua C API. This function does not
   -- return.   The `level` argument behaves just like the core `error`
   -- function.
   -- @function argerror
   -- @string name function to callout in error message
   -- @int i argument number
   -- @string[opt] extramsg additional text to append to message inside parentheses
   -- @int[opt=1] level call stack level to blame for the error
   -- @see resulterror
   -- @see extramsg_mismatch
   -- @usage
   --    local function slurp(file)
   --       local h, err = input_handle(file)
   --       if h == nil then
   --          argerror('std.io.slurp', 1, err, 2)
   --       end
   --       ...
   argerror = _typecheck.argscheck(
      'argerror', T.stringy, T.integer, T.accept, opt(T.integer)
   ) .. _typecheck.argerror,

   --- Wrap a function definition with argument type and arity checking.
   -- In addition to checking that each argument type matches the corresponding
   -- element in the *types* table with `argcheck`, if the final element of
   -- *types* ends with an ellipsis, remaining unchecked arguments are checked
   -- against that type:
   --
   --     format = argscheck('string.format(string, ?any...)', string.format)
   --
   -- A colon in the function name indicates that the argument type list does
   -- not have a type for `self`:
   --
   --     format = argscheck('string:format(?any...)', string.format)
   --
   -- If an argument can be omitted entirely, then put its type specification
   -- in square brackets:
   --
   --     insert = argscheck('table.insert(table, [int], ?any)', table.insert)
   --
   -- Similarly return types can be checked with the same list syntax as
   -- arguments:
   --
   --     len = argscheck('string.len(string) => int', string.len)
   --
   -- Additionally, variant return type lists can be listed like this:
   --
   --     open = argscheck('io.open(string, ?string) => file or nil, string',
   --                       io.open)
   --
   -- @function argscheck
   -- @string decl function type declaration string
   -- @func inner function to wrap with argument checking
   -- @usage
   --    local case = argscheck('std.functional.case(?any, #table) => [any...]',
   --       function(with, branches)
   --          ...
   --       end)
   --
   --    -- Alternatively, as an annotation:
   --    local case = argscheck 'std.functional.case(?any, #table) => [any...]' ..
   --    function(with, branches)
   --       ...
   --    end
   argscheck = argscheck,

   --- Checks the type of *actual* against the *expected* typespec
   -- @function check
   -- @tparam string expected expected typespec
   -- @param actual object being typechecked
   -- @treturn[1] bool `true`, if *actual* matches *expected*
   -- @return[2] `nil`
   -- @treturn[2] string an @{extramsg_mismatch} format error message, otherwise
   -- @usage
   --    --> stdin:2: string or number expected, got empty table
   --    assert(check('string|number', {}))
   check = checktypespec,

   --- Format a type mismatch error.
   -- @function extramsg_mismatch
   -- @string expected a pipe delimited list of matchable types
   -- @param actual the actual argument to match with
   -- @number[opt] index erroring container element index
   -- @treturn string formatted *extramsg* for this mismatch for @{argerror}
   -- @see argerror
   -- @see resulterror
   -- @usage
   --    if fmt ~= nil and type(fmt) ~= 'string' then
   --       argerror('format', 1, extramsg_mismatch('?string', fmt))
   --    end
   extramsg_mismatch = function(expected, actual, index)
      return extramsg_mismatch(typesplit(expected), actual, index)
   end,

   --- Format a too many things error.
   -- @function extramsg_toomany
   -- @string bad the thing there are too many of
   -- @int expected maximum number of *bad* things expected
   -- @int actual actual number of *bad* things that triggered the error
   -- @see argerror
   -- @see resulterror
   -- @see extramsg_mismatch
   -- @usage
   --    if select('#', ...) > 7 then
   --       argerror('sevenses', 8, extramsg_toomany('argument', 7, select('#', ...)))
   --    end
   extramsg_toomany = extramsg_toomany,

   --- Compact permutation list into a list of valid types at each argument.
   -- Eliminate bracketed types by combining all valid types at each position
   -- for all permutations of *typelist*.
   -- @function parsetypes
   -- @tparam list types a normalized list of type names
   -- @treturn list valid types for each positional parameter
   parsetypes = parsetypes,

   --- Raise a bad result error.
   -- Like @{argerror} for bad results. This function does not
   -- return.   The `level` argument behaves just like the core `error`
   -- function.
   -- @function resulterror
   -- @string name function to callout in error message
   -- @int i result number
   -- @string[opt] extramsg additional text to append to message inside parentheses
   -- @int[opt=1] level call stack level to blame for the error
   -- @usage
   --    local function slurp(file)
   --       ...
   --       if type(result) ~= 'string' then
   --          resulterror('std.io.slurp', 1, err, 2)
   --       end
   resulterror = _typecheck.argscheck(
      'resulterror', T.stringy, T.integer, T.accept, opt(T.integer)
   ).. resulterror,

   --- Split a typespec string into a table of normalized type names.
   -- @function typesplit
   -- @tparam string|table either `"?bool|:nometa"` or `{"boolean", ":nometa"}`
   -- @treturn table a new list with duplicates removed and leading '?'s
   --    replaced by a 'nil' element
   typesplit = typesplit,

}, {

   --- Metamethods
   -- @section metamethods

   --- Lazy loading of typecheck modules.
   -- Don't load everything on initial startup, wait until first attempt
   -- to access a submodule, and then load it on demand.
   -- @function __index
   -- @string name submodule name
   -- @treturn table|nil the submodule that was loaded to satisfy the missing
   --    `name`, otherwise `nil` if nothing was found
   -- @usage
   --    local version = require 'typecheck'.version
   __index = function(self, name)
      local ok, t = pcall(require, 'typecheck.' .. name)
      if ok then
         rawset(self, name, t)
         return t
      end
   end,
})
