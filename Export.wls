#!/usr/bin/env wolframscript

export[libName_String] := Module[{
    $directory, $destination, $source, $sourceCode, $funcs, 
    getName, getArgs, getReturn, $codeTemplate, $usageTemplate, $metainfoCode, $metainfoUsage, 
    $codeString, $typeRulesRes, $typeRulesArg
}, 
    $directory = DirectoryName[$InputFileName];

    $destination = AbsoluteFileName[FileNameJoin[{$directory, "Kernel", libName <> ".wl"}]];

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
            " = " ~~ ___ ~~ "MArgument_get" ~~ type__ ~~ 
            "(Args[" ~~ num_ ~~ "])"
        ] :> {name, type, ToExpression[num] + 1}
    ]&;

    getReturn[func_String] := StringCases[func, 
        Shortest["MArgument_set" ~~ returnType__ ~~ 
            "(Res," ~~ resName__ ~~ ");"
        ] :> {StringTrim[returnType], StringTrim[resName]}
    ];

    $usageTemplate = StringTemplate["`name`::usage = \"`name`[`argNames`] -> `returnName`\";"];

    $codeTemplate = StringTemplate["`name` = LibraryFunctionLoad[$libFile, \"`name`\", `args`, `return`];"]; 

    $typeRulesArg = {
        "Integer" -> "Integer",
        "UTF8String" -> "String",
        "MTensor" -> "{Integer, 1}",
        "MNumericArray" -> "{\"ByteArray\", \"Shared\"}"
    };

    $typeRulesRes = {
        "Integer" -> "Integer",
        "UTF8String" -> "String",
        "MTensor" -> "{Integer, 1}",
        "MNumericArray" -> "\"ByteArray\""
    };

    $metainfoCode = StringRiffle[Map[$codeTemplate @ <|
        "name" -> getName[#], 
        "args" -> Function[n, If[getName[#] === "socketSend", Print[getArgs[#]]; n, n]][(Query[All, 2] @ SortBy[Last] @ getArgs[#]) /. $typeRulesArg], 
        "argNames" -> StringRiffle[Query[All, 1] @ SortBy[Last] @ getArgs[#], ", "], 
        "return" -> getReturn[#][[1, 1]] /. $typeRulesRes, 
        "returnName" -> getReturn[#][[1, 2]]
    |>&, $funcs], "\n\n\n"];

    $metainfoUsage = StringRiffle[Map[$usageTemplate @ <|
        "name" -> getName[#], 
        "args" -> Query[All, 2] @ SortBy[Last] @ getArgs[#], 
        "argNames" -> StringRiffle[Query[All, 1] @ SortBy[Last] @ getArgs[#], ", "], 
        "return" -> getReturn[#][[1, 1]], 
        "returnName" -> getReturn[#][[1, 2]]
    |>&, $funcs], "\n\n\n"];

    $codeString = Import[$destination, "Text"];

    $codeString = StringReplace[$codeString, {
        "(*Library Functions*)" ~~ __ ~~ "Begin[\"`Private`\"]" -> "(*Library Functions*)\n\n\n" <> $metainfoUsage <> "\n\n\nBegin[\"`Private`\"]",
        "(*Library Functions*)" ~~ __ ~~ "End[]" -> "(*Library Functions*)\n\n\n" <> $metainfoCode <> "\n\n\nEnd[]"
    }];

    WriteString[$destination, $codeString];
];


export["csockets"];
