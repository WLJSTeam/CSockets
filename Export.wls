#!/usr/bin/env wolframscript

export[libName_String] := Module[{
    $directory, $destination, $source, $sourceCode, $funcs, 
    getName, getArgs, getReturn, $codeTemplate, $metainfo
}, 
    $directory = DirectoryName[$InputFileName];

    $destination = FileNameJoin[{$directory, "Kernel", "LibraryFunctions.wl"}];

    $source = FileNameJoin[{$directory, "Source", libName <> ".c"}];

    $sourceCode = Import[$source, "String"];

    $funcs = StringCases[$sourceCode, 
        Shortest["DLLEXPORT int " ~~ __ ~~ 
            "(WolframLibraryData libData, " ~~ __ ~~ "\n}"
        ]
    ];

    getName = First @ StringCases[#, 
        Shortest["DLLEXPORT int " ~~ name: LetterCharacter.. ~~ "(WolframLibraryData libData, "] ~~ __ :> name
    ]&; 

    getArgs = StringCases[#, 
        Shortest[{" *", " "} ~~ (name: LetterCharacter..) ~~ 
            " = " ~~ __ ~~ "MArgument_get" ~~ type__ ~~ 
            "(Args[" ~~ num_ ~~ "])"
        ] :> {name, type, ToExpression[num] + 1}
    ]&;

    getReturn[func_String] := StringCases[func, 
        Shortest["MArgument_set" ~~ returnType__ ~~ 
            "(Res," ~~ resName__ ~~ ");"
        ] :> {returnType, resName}
    ];

    $codeTemplate = StringTemplate["`name` = LibraryFunctionLoad[$lib, \"`name`\", `args`, `return`];"];

    $metainfo = StringRiffle[Map[$codeTemplate @ <|"name" -> getName[#], "args" -> getArgs[#], "return" -> getArgs[#]|>&, $funcs], "\n\n"];

    Echo[$metainfo]
];


export["csockets"];
