#!/usr/bin/env lua
-- inc - manipulate unsinged integers in strings
--
-- Copyright (c) 2013, Jens Oliver John )joj (mailswirl) 2ion dot de(
-- All rights reserved.
-- 
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions are met:
--     * Redistributions of source code must retain the above copyright
--       notice, this list of conditions and the following disclaimer.
--     * Redistributions in binary form must reproduce the above copyright
--       notice, this list of conditions and the following disclaimer in the
--       documentation and/or other materials provided with the distribution.
--     * Neither the name of the author nor the
--       names of its contributors may be used to endorse or promote products
--       derived from this software without specific prior written permission.
-- 
-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
-- ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
-- WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
-- DISCLAIMED. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY
-- DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
-- (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
-- LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
-- ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
-- (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
-- SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

local tx = require 'pl.tablex'

-- FUNCTION DEFINITIONS

local function die(t)
    print(string.format(unpack(t)))
    os.exit(1)
end

local function usage()
    print([[
inc - manipulate unsigned integers in strings
Copyright (c) 2013, Jens Oliver John )joj (mailswirl) 2ion dot de(
All rights reserved.

Invocation:
    inc <verblist> <string>
        Applies <verlist> onto <string>, printing the result to stdout.
    inc -c <string>
        Prints a modified copy of <string> where
            * all recognized numbers are in bright/bold yellow and
            * the numbers' occurences are prefixed with their individual
              number_index values,
        so that if the string is long, it is still easy to formulate a
        verblist.
    inc -h
        Prints this message and exits.

Where:
    <verblist>  := ',' <verb1> ',' <verb2> [...] ',' <verbN>
    <verb>      := [+-]?<number_index>[+-=]<number_delta>[/<digitcount>]
    <string>    := A string with at least a single digit character. At
                   this point, all numbers will be parsed *UNSIGNED*.

Examples:
    inc ,-1+5 $string
        Increment the first last number by 5
    
    inc ,-2-3 $string
        Decrement the second last number by 3

    inc ,1-3,-2-4 $string
        Decrement the first number by 3 and decrement the second
        last number by 4.

    inc ,+1+3,3=4 $string
        Increment the first number by 3 and set the third number
        to 4.

    inc ,1+3,3=4/7 $string
        Increment the first number by 3 and set the third number
        to 4, and express the 3rd number as a 7 digit number, ie.
        `0000004`.

    inc ,0-50 $string
        Decrement all numbers by 50.

    inc ,0+0/5 $string
        Express all numbers in $string with 5 digits without altering them.

Return values:
    0 in case of success, 1 in case of an error.
    ]])
end

local function parse_string(s)
    local n, nt = {}, {}
    local p = 1
    local ni = 1
    while p <= #s do
        local i,j,k = s:find("([%d]+)", p)
        if not i then break end
        if n[#n] then
            local k,l = n[#n][2]+1, i-1
            table.insert(n, { k, l, s:sub(k, l) })
        else
            local k,l = 1, i-1
            table.insert(n, { k, l, s:sub(k, l) })
        end
        table.insert(n, { i, j, k, ni })
        table.insert(nt, n[#n])
        ni = ni + 1
        p = j+1
    end
    if p <= #s then
        local k,l = p, #s
        table.insert(n, { p, #s, s:sub(k, l) })
    end
    return n, nt
end

local function parse_verbs(vstr)
    local v = {}
    for verb, index, rel, delta, opt in vstr:gmatch("(,([+-]?[%d]+)([+-=])([%d]+)([/%d]*))") do
        table.insert(v, { index=index, rel=rel, delta=delta, opt=opt })
    end
    -- convert index :: string to index :: int, respecting the prefixes,
    -- and remove the /prefix from opt
    tx.foreachi(v, function (verb)
        -- verb.index
        if verb.index:match("^[+-][%d]+") then
            local idxrel, index = verb.index:match("^([+-])([%d]+)")
            if idxrel == '-' then
                verb.index = -1 * tonumber(index)
            else
                verb.index = tonumber(index)
            end
        else
            verb.index = tonumber(verb.index)
        end
        -- verb.rel
        if verb.rel == '+' or verb.rel == '=' then
            verb.delta = tonumber(verb.delta)
        elseif verb.rel == '-' then
            verb.delta = -1 * tonumber(verb.delta)
        end
        -- verb.opt
        if verb.opt then
            local opt = verb.opt:match("^/([%d]+)")
            verb.opt = tonumber(opt)
        end
    end)
    return v
end

local function apply_verbs(v, n, nt)
    tx.foreachi(v, function (verb)
        local function validate_verb(verb)
            if verb.index ~= 0 and
                ((verb.index < 0 and (-1*verb.index) > #nt) or
                (verb.index > 0 and verb.index > #nt)) then
                die{ "number index <%s> is out of bounds!", verb.index }
            end
        end
        validate_verb(verb)
        if verb.index == 0 then
            tx.foreachi(nt, function (target)
                local tvalue = target[3]
                if verb.rel ~= '=' then
                    tvalue = tvalue + verb.delta
                else
                    tvalue = verb.delta
                end
                if verb.opt then
                    tvalue = string.format("%0" .. verb.opt .. "d", tvalue)
                end
                target[3] = tvalue
            end)
        else
            local target_index = verb.index > 0 and verb.index or (#nt + verb.index + 1)
            local target = nt[target_index]
            local tvalue = target[3]
            if verb.rel ~= '=' then
                tvalue = tvalue + verb.delta
            else
                tvalue = verb.delta
            end
            if verb.opt then
                tvalue = string.format("%0" .. verb.opt .. "d", tvalue)
            end
            target[3] = tvalue
        end
    end)
end

local function concat(n)
    return table.concat(tx.imap(function (v) return v[3] end, n))
end

local function color_numbers(n)
    return table.concat(tx.imap(function (v)
        if v[4] then
            return string.format("\27[1;34m(%d)\027[1;33m%s\027[0;m", v[4], v[3])
        else
            return v[3]
        end
    end, n))
end

-- MAIN()

if #arg < 1 or (arg[1] == '-c' and #arg < 2) then
    die{"Too few arguments. Run with the -h option for usage instructions."}
elseif arg[1] == '-h' then
    usage()
    os.exit(0)
elseif arg[1] == '-c' then
    print(color_numbers(parse_string(arg[2])))
else
    if not arg[1] or not arg[2] or #arg[1] == 0 or #arg[2] == 0 then
        die{"Too few arguments or empty strings. Run with the -h option for usage instructions."}
    end
    local n, nt = parse_string(arg[2])
    if #nt == 0 then
        die{"The string passed does not contain any numbers!"}
    end
    local v = parse_verbs(arg[1])
    apply_verbs(v, n, nt)
    print(concat(n))
    os.exit(0)
end

--local n, nt = parse_string(test)
--print("Input string:")
--print(color_numbers(n))
--print("Parsing verbs ...")
--local v = parse_verbs(arg[1])
--print("Applying verbs ...")
--apply_verbs(v, n, nt)
--print(color_numbers(n))
