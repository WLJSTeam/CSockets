#!/usr/bin/env wolframscript

Get["CCompilerDriver`"];
Get["LibraryLink`"];


$libraryLinkVersion =
LibraryVersionInformation[FindLibrary["demo"]]["WolframLibraryVersion"];


$directory =
DirectoryName @ If[$InputFileName == "", NotebookFileName[], $InputFileName];


$sourceDirectory =
FileNameJoin[{$directory, "Source"}];


$sourceFiles =
FileNames["*.c", {$sourceDirectory}];


$libraryDirectory =
FileNameJoin[{$directory, "LibraryResources", $SystemID <> "-v" <> ToString[$libraryLinkVersion]}];


$packageDirectory =
FileNameJoin[{$directory, "Kernel"}];


If[!FileExistsQ[$libraryDirectory], CreateDirectory[$libraryDirectory]];


$libraryFile = build[library_String, prot_: Automatic] :=
CreateLibrary[$sourceFiles, library,
    "TargetDirectory" -> $libraryDirectory,
    "Debug" -> True,
    "TransferProtocolLibrary" -> prot,
    "ShellCommandFunction" -> Print,
    "ShellOutputFunction" -> Print,
    "SystemCompileOptions" -> "/Ox /GL",
    "IncludeDirectories" -> {$sourceDirectory}
];


build["csockets"];


snakeToCamelCase[str_String] :=
StringReplace[str, "_" ~~ c: LetterCharacter :> ToUpperCase[c]];


parseDefinition[definition_String] :=
Module[{$name, $argTypes, $argNames, $argNumbers, $argLines, $resultLines},
    $name = StringCases[definition,
        Shortest[
            "DLLEXPORT int " ~~
            name__ ~~
            "(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)"] :> name][[1]];

    $argLines = Select[StringContainsQ[#, "MArgument_get"]&] @ StringSplit[definition, "\n"];

    $argNames = Map[StringCases[#,
        Shortest[LetterCharacter.. ~~ {" *", " ", "* "} ~~ (argName: {"_", LetterCharacter}..) ~~ {" =", "="} ~~ ___ ~~ "MArgument_get"] :>
            snakeToCamelCase[argName]
    ][[1]]&] @ $argLines;

    $argTypes = Map[StringCases[#,
        Shortest["MArgument_get" ~~ type__ ~~ "("] :> (type /. {
            "UTF8String" -> String,
            "Integer" -> Integer,
            "Real" -> Real,
            "Boolean" -> Boolean,
            "Complex" -> Complex,
            "MNumericArray" -> {"\"ByteArray\"", "\"Shared\""},
            "MTensor" -> {Integer, 1}
        })
    ][[1]]&] @ $argLines;

    $argNumbers = Map[StringCases[#,
        Shortest["MArgument_get" ~~ __ ~~ "(Args[" ~~ num__ ~~ "]"] :> ToExpression[num]
    ][[1]]&] @ $argLines;

    $resultLines = Select[StringContainsQ[#, "MArgument_set"]&] @ StringSplit[definition, "\n"];

    If[$resultLines =!= {},
        $resultType = StringCases[$resultLines[[1]], Shortest["MArgument_set" ~~ type__ ~~ "("] :> (type /. {
            "UTF8String" -> String,
            "Integer" -> Integer,
            "Real" -> Real,
            "Boolean" -> Boolean,
            "Complex" -> Complex,
            "MNumericArray" -> "\"ByteArray\"",
            "MTensor" -> {Integer, 1}
        })][[1]],
        $resultType = "\"Void\""
    ];

    If[$resultType == {Integer, 1},
        $resultType = {Integer, First[StringCases[definition,
            Shortest["MTensor_new(MType_Integer," ~~ n__ ~~ ","] :> ToExpression[n]
        ]]}
    ];

    $resultName = If[$resultType === "\"Void\"",
        "",
        StringCases[$resultLines[[-1]], Shortest["MArgument_set" ~~ __ ~~ "(Res," ~~ name__ ~~ ")"] :>
            snakeToCamelCase[StringTrim[name]]][[1]]
    ];

    StringTemplate["`1`::usage =\n\"`1`[`3`]`6`.\";\n\n\n`1` =\nLibraryFunctionLoad[$CSocketsLibrary, \"`1`\", `2`, `5`];"][
        $name, $argTypes, StringRiffle[$argNames, ", "], $argNumbers, $resultType, If[# === "", "", " -> " <> #]& @ $resultName]
];


bind[context_String, library_String] :=
Module[{code, definitions, bindCode},
    code = StringRiffle[Map[Import[#, "String"]&] @ $sourceFiles, "\n\n\n"];

    definitions = StringCases[code, Shortest["DLLEXPORT int " ~~ LetterCharacter.. ~~ "(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)" ~~ __ ~~ "\n}"]];

    bindCode = StringRiffle[Flatten @ {
        "(* ::Package:: *)",
        "BeginPackage[\"" <> context <> "\", {\"LibraryLink`\", \"CCompilerDriver`\"}];",
        "$CSocketsLibrary =\nFileNameJoin[{DirectoryName[$InputFileName, 2], \"LibraryResources\", $SystemID <> \"-v\" <> ToString[8], \"" <> library <> ".\" <> Internal`DynamicLibraryExtension[]}];",
        Map[parseDefinition] @ definitions,
        "EndPackage[];"
    }, "\n\n\n"];

    WriteString[FileNameJoin[{$packageDirectory, StringSplit[context, "`"][[-1]] <> ".wl"}], bindCode];
];


bind["WLJS`CSockets`Library`", "csockets"];