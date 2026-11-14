## Wolfram Language Code Style Guide

- Use two blank lines between blocks in a .wl file.
- Use only one blank line after (* :Package: *) because it affects formatting and display in Mathematica.
- In a multiline Begin or BeginPackage expression, keep the first argument (the package name) on the first line. 
- Use 4 spaces for indentation.
- Do not use tabs.
- Place the left-hand side of a function definition (before :=) on the first line.
- Place the right-hand side of a function definition on the next line. 
- Example:

```wl
funcName[x_, y_] :=
x + y;
```

- Separate symbols, operators, and words with spaces, except at the end of a line and as specified by the exceptions below.
- End every definition with a semicolon.
- Do not put a space before a comma; put a space after it. Example: `{1, 2, 3, 4}`.
- Do not put a space after `!` (the `Not` operator).
- Do not put a space before `:` (the `Pattern` function).
- Do not put a space before `&` (the function terminator in `(# + 1)&`).
- Treat /@, /:, /;, /@@, @*, and other operator shorthands as single operators. Do not insert spaces inside them.
- Do not put a space before a semicolon; put a space after it unless it ends the line. Example: `x = 1;`.
- Write all usage declarations on two or more lines, like function definitions. Example:

```wl
funcName::usage = 
"funcName[x, y] - returns x + y.";
```

- Long signatures on the left-hand side of definitions may span multiple lines.

```wl
func[
    x, y, z,
    z, b, c
] := 
Total[{x, y, z, a, b, c}];
```

- Use the most precise argument types possible: `f[x_]` is discouraged; `createAddressStorage[host_String, port_Integer]` is preferred.
- Definitions of nonlocal internal package variables and constants should also span two or more lines when the right-hand side is long: put the left-hand side and equals sign on the first line, and the right-hand side on the next. Keep short definitions such as `$const = 1.0` on one line when the right-hand side is not a complex code block.

```wl
$directory = 
DirectoryName[..];
```

- For memoized constants and global variables, keep the left-hand side on one line.

```wl
$icon := $icon =
Import["icon.png"];
```

- Format multiline expressions, lists, and associations in C# block style. Examples:

```wl
(*standalone multiline list*)
{
    1, 
    2, 
    3
}


(*standalone multiline association*)
<|
    1 -> 2, 
    2 -> 3, 
    3 -> 1
|>


(*standalone multiline expression*)
expr[
    1, 
    2 -> 3, 
    f[x]
]
```

- When assigning a multiline list, expression, or association, place its opening on the same line as the assignment.

```wl
(*multiline list assignment*)
l = {
    1, 
    2, 
    3
};


(*multiline association assignment*)
a = <|
    1 -> 2, 
    2 -> 3, 
    3 -> 1
|>;


(*multiline expression assignment*)
e = expr[
    1, 
    2 -> 3, 
    f[x]
];
```

- For scoping constructs, keep a short first argument on the first line. If it is long, keep the opening of its list on the first line.

```wl
With[{x = 1}, 
    x + 1
];


Module[{
    x = 1, 
    y = 2
}, 
    x + y
];
```

- In a multiline If or Switch expression, keep the condition or selector on the first line.

```wl
If[x != y, 
    x, 
    y
];


Swicth[x, 
    1, 2, 
    2, 3
];
```

## Build

- Build the project from the repository root with `wolframscript -f Build.wls`.
- The build also runs the bindings generator: it inserts Wolfram Language declarations using `LibraryFunctionLoad` into `Kernel/CSockets.wl` to load the exported native library functions.
- Rebuild after changing native code or exported function signatures so that the compiled library and generated bindings stay in sync.

## Wolfram Engine and tests

- This environment uses Wolfram Engine with a free license, which limits the number of concurrent kernel processes. Run Wolfram commands, builds, and tests sequentially; never launch them in parallel.
- Wolfram Engine can occasionally terminate unexpectedly in this environment. If a test process exits with a nonzero exit code, retry it once, after the previous process has exited.
- A process crash does not by itself establish a test failure. Report persistent process failures separately from failed test assertions.
