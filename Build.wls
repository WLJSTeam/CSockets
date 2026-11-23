#!/usr/bin/env wolframscript

Get["CCompilerDriver`"];
Get["LibraryLink`"];


(* Configuration. Usage: wolframscript -f Build.wls [library-file] [bindings.wl] *)
$directory = DirectoryName[$InputFileName];


$arguments = Rest[$ScriptCommandLine];


$libraryLinkVersion = Which[
    $VersionNumber >= 14.3, 8,
    $VersionNumber >= 13.1, 7,
    $VersionNumber >= 12.1, 6,
    $VersionNumber >= 12.0, 5,
    $VersionNumber >= 11.2, 4,
    $VersionNumber >= 10.0, 3,
    $VersionNumber >= 9.0, 2,
    True, 1
];


$sourceDirectory = FileNameJoin[{$directory, "Source"}];


$sourceFiles = FileNames["*.c", $sourceDirectory];


$libraryDirectory = FileNameJoin[{
    $directory, "LibraryResources", $SystemID <> "-v" <> ToString[$libraryLinkVersion]
}];


$libraryFile = If[Length[$arguments] >= 1,
    ExpandFileName[First[$arguments]],
    FileNameJoin[{$libraryDirectory, "csockets." <> Internal`DynamicLibraryExtension[]}]
];


$packageFile = If[Length[$arguments] >= 2,
    ExpandFileName[$arguments[[2]]],
    FileNameJoin[{$directory, "Kernel", "CSockets.wl"}]
];


$compileOptions = If[$OperatingSystem === "Windows", "/Ox /GL", "-O3"];


$libraryMarker = "(* :LibraryLoad: *)";


$identifierPattern = RegularExpression["[A-Za-z_][A-Za-z_0-9]*"];
(* Literals and comments are recognized before punctuation. Line splices are removed first. *)
$cTokenPattern = RegularExpression[
    "(?s)/\\*.*?\\*/|//[^\\r\\n]*|\"(?:\\\\.|[^\"\\\\])*\"|'(?:\\\\.|[^'\\\\])*'|[A-Za-z_][A-Za-z_0-9]*|[0-9]+|[^\\s]"
];


$argumentTypes = <|
    "UTF8String" -> String, "Integer" -> Integer, "Real" -> Real,
    "Boolean" -> (True | False), "Complex" -> Complex,
    "MNumericArray" -> {"ByteArray", "Shared"},
    "DataStore" -> "DataStore", "MTensor" -> {Integer, 1}
|>;


$resultTypes = Join[$argumentTypes, <|"MNumericArray" -> "ByteArray"|>];


fail[text_String] :=
Throw[Failure["Build", <|"MessageTemplate" -> text|>]];


cTokens[code_String] :=
Select[
    StringCases[StringReplace[code, {"\\\r\n" -> "", "\\\n" -> ""}], $cTokenPattern],
    !StringStartsQ[#, {"/*", "//"}]&
];


(* Match nested (), [] and {} independently of source formatting. *)
closingToken[tokens_List, start_Integer] :=
Module[{stack = {}, pairs = <|"(" -> ")", "[" -> "]", "{" -> "}"|>, token, result = 0},
    Do[
        token = tokens[[i]];
        If[KeyExistsQ[pairs, token],
            AppendTo[stack, pairs[token]],
            If[MemberQ[{")", "]", "}"}, token],
                If[stack === {} || Last[stack] =!= token, fail["Unbalanced C delimiters."]];
                stack = Most[stack];
                If[stack === {}, result = i; Break[]];
            ];
        ],
        {i, start, Length[tokens]}
    ];
    If[result === 0, fail["Unterminated C expression."]];
    result
];


splitArguments[tokens_List] :=
Module[{result = {}, start = 1, i = 1},
    While[i <= Length[tokens],
        If[MemberQ[{"(", "[", "{"}, tokens[[i]]],
            i = closingToken[tokens, i],
            If[tokens[[i]] === ",",
                AppendTo[result, Take[tokens, {start, i - 1}]];
                start = i + 1;
            ];
        ];
        i++;
    ];
    Append[result, Drop[tokens, start - 1]]
];


getFunctionDefinitions[code_String] :=
Module[{tokens = cTokens[code], definitions = {}, i = 1, end, body},
    While[i <= Length[tokens],
        If[tokens[[i]] === "DLLEXPORT",
            end = i + 1;
            While[end <= Length[tokens] && !MemberQ[{"(", ";"}, tokens[[end]]], end++];
            If[end <= Length[tokens] && tokens[[end]] === "(",
                body = closingToken[tokens, end] + 1;
                If[body <= Length[tokens] && tokens[[body]] === "{",
                    body = closingToken[tokens, body];
                    AppendTo[definitions, Take[tokens, {i, body}]];
                    i = body;
                ];
            ];
        ];
        i++;
    ];
    definitions
];


getFunctionName[definition_List] :=
definition[[First[FirstPosition[definition, "("]] - 1]];


getFunctionDefinition[code_String, name_String] :=
Module[{positions, tokens, definitions, match, start, finish},
    positions = StringPosition[code, $cTokenPattern, Overlaps -> False];
    positions = Select[positions, !StringStartsQ[StringTake[code, #], {"/*", "//"}]&];
    tokens = StringTake[code, #]& /@ positions;
    definitions = getFunctionDefinitions[code];
    match = Select[definitions, getFunctionName[#] === name&];
    If[Length[match] =!= 1, fail["Expected one definition of " <> name <> "."]];
    start = First[First[SequencePosition[tokens, First[match]]]];
    finish = start + Length[First[match]] - 1;
    StringTake[code, {First[positions[[start]]], Last[positions[[finish]]]}]
];


getCalls[definition_List, prefix_String] :=
Module[{calls = {}, end},
    Do[
        If[StringStartsQ[definition[[i]], prefix] && definition[[i + 1]] === "(",
            end = closingToken[definition, i + 1];
            AppendTo[calls, <|
                "Type" -> StringDrop[definition[[i]], StringLength[prefix]],
                "Arguments" -> splitArguments[Take[definition, {i + 2, end - 1}]],
                "Position" -> i
            |>];
        ],
        {i, Length[definition] - 1}
    ];
    calls
];


snakeToCamelCase[name_String] :=
StringReplace[name, "_" ~~ c: LetterCharacter :> ToUpperCase[c]];


getArguments[definition_List] :=
Module[{arguments, before, equals, indices, index, name},
    arguments = Map[Function[call,
        indices = Cases[call["Arguments"], {"Args", "[", n_String, "]"} :> n];
        If[Length[indices] =!= 1 || !StringMatchQ[First[indices], DigitCharacter..],
            fail["Expected a literal Args[index] in " <> getFunctionName[definition]]
        ];
        index = FromDigits[First[indices]];
        before = Take[definition, call["Position"] - 1];
        equals = Flatten[Position[before, "="]];
        If[equals === {}, fail["Argument getter must initialize a named variable."]];
        name = before[[Last[equals] - 1]];
        If[!StringMatchQ[name, $identifierPattern], fail["Cannot identify argument variable."]];
        <|"Index" -> index, "Name" -> snakeToCamelCase[name], "Type" ->
            Lookup[$argumentTypes, call["Type"], fail["Unsupported argument type: " <> call["Type"]]]|>
    ], getCalls[definition, "MArgument_get"]];
    arguments = DeleteDuplicates[arguments];
    arguments = SortBy[arguments, #["Index"]&];
    If[Lookup[arguments, "Index", {}] =!= Range[0, Length[arguments] - 1],
        fail["Argument indices must be unique and contiguous in " <> getFunctionName[definition]]
    ];
    arguments
];


getArgumentNames[definition_List] :=
Lookup[getArguments[definition], "Name", {}];


getArgumentTypes[definition_List] :=
Lookup[getArguments[definition], "Type", {}];


getReturnType[definition_List] :=
Module[{calls = getCalls[definition, "MArgument_set"], types, tensors, ranks},
    If[calls === {}, Return["Void"]];
    types = DeleteDuplicates[Lookup[calls, "Type"]];
    If[Length[types] =!= 1, fail["Conflicting result types in " <> getFunctionName[definition]]];
    If[First[types] === "MTensor",
        tensors = getCalls[definition, "MTensor_new"];
        ranks = DeleteDuplicates[Cases[Lookup[tensors, "Arguments"],
            {{"MType_Integer"}, {rank_String}, __} /; StringMatchQ[rank, DigitCharacter..] :> FromDigits[rank]
        ]];
        If[tensors === {} && getCalls[definition, "MTensorFromSocket"] =!= {}, ranks = {1}];
        If[Length[ranks] =!= 1, fail["Cannot infer integer tensor rank in " <> getFunctionName[definition]]];
        Return[{Integer, First[ranks]}];
    ];
    Lookup[$resultTypes, First[types], fail["Unsupported result type: " <> First[types]]]
];


getResultName[definition_List] :=
Module[{calls = getCalls[definition, "MArgument_set"], args},
    If[calls === {}, Return[""]];
    args = Last[calls]["Arguments"];
    (* Custom setters accept libData before Res. *)
    args = Drop[args, First[FirstPosition[args, {"Res"}]]];
    If[args === {}, fail["Missing result value."]];
    If[Length[First[args]] === 1 && StringMatchQ[First[First[args]], $identifierPattern],
        snakeToCamelCase[First[First[args]]],
        ""
    ]
];


libraryLinkFunctionQ[definition_List] :=
Module[{start = First[FirstPosition[definition, "("]], parameters},
    parameters = splitArguments[Take[definition, {start + 1, closingToken[definition, start] - 1}]];
    Length[parameters] === 4 && First[First[parameters]] === "WolframLibraryData"
];


generateBinding[definition_List] :=
Module[{
    name = getFunctionName[definition],
    resultName = getResultName[definition],
    resultType = getReturnType[definition]
},
    If[resultName === "" && resultType =!= "Void",
        resultName = If[StringQ[resultType], resultType, ToString[resultType, InputForm]];
    ];
    StringTemplate["`1`::usage =\n\"`1`[`2`]`3`.\";\n\n\n`1` =\nLibraryFunctionLoad[$library, \"`1`\", `4`, `5`];"][
        name, StringRiffle[getArgumentNames[definition], ", "],
        If[resultName === "", "", " -> " <> resultName],
        ToString[getArgumentTypes[definition], InputForm], ToString[resultType, InputForm]
    ]
];


(* Mask WL strings and nested comments, preserving source offsets. *)
maskWolframCode[code_String, preserveMarker: True | False: False] :=
Module[{chars = Characters[code], depth = 0, quoted = False, i = 1, pair, output},
    output = chars;
    While[i <= Length[chars],
        pair = StringJoin[Take[chars, {i, Min[i + 1, Length[chars]]}]];
        Which[
            preserveMarker && depth === 0 && !quoted &&
                StringTake[code, {i, Min[i + StringLength[$libraryMarker] - 1, StringLength[code]]}] === $libraryMarker,
                i += StringLength[$libraryMarker] - 1,
            depth > 0,
                output[[i]] = " ";
                Which[
                    pair === "(*", depth++; output[[i + 1]] = " "; i++,
                    pair === "*)", depth--; output[[i + 1]] = " "; i++
                ],
            quoted,
                output[[i]] = " ";
                Which[
                    chars[[i]] === "\\" && i < Length[chars], output[[i + 1]] = " "; i++,
                    chars[[i]] === "\"", quoted = False
                ],
            pair === "(*", depth = 1; output[[i]] = " "; output[[i + 1]] = " "; i++,
            chars[[i]] === "\"", quoted = True; output[[i]] = " "
        ];
        i++;
    ];
    StringJoin[output]
];


insertBindings[code_String, bindings_String] :=
Module[{marker, ends, start, finish, prefix},
    marker = StringPosition[maskWolframCode[code, True], $libraryMarker];
    start = If[marker === {}, 1, Last[First[marker]] + 1];
    (* Locate the closing private context after the marker. *)
    ends = StringPosition[maskWolframCode[code], RegularExpression["\\bEnd\\s*\\[\\s*\\]\\s*;"]];
    ends = Select[ends, First[#] >= start&];
    If[ends === {}, fail["Bindings target has no End[]; after the library marker."]];
    finish = First[First[ends]];
    prefix = If[marker === {}, StringTake[code, finish - 1] <> $libraryMarker,
        StringTake[code, start - 1]
    ];
    prefix <> "\n\n\n" <> bindings <> "\n\n\n" <> StringDrop[code, finish - 1]
];


build[] :=
Module[{definitions, bindings, package, output, compiled},
    If[Length[$arguments] > 2, fail["Usage: Build.wls [library-file] [bindings.wl]"]];
    If[FileExtension[$libraryFile] =!= Internal`DynamicLibraryExtension[],
        fail["Library filename must use the current platform's dynamic library extension."]
    ];
    If[FileExtension[$packageFile] =!= "wl", fail["Bindings target must be a .wl file."]];
    definitions = Flatten[getFunctionDefinitions[Import[#, "String"]]& /@ $sourceFiles, 1];
    definitions = Select[definitions, libraryLinkFunctionQ];
    If[definitions === {}, fail["No exported LibraryLink functions found."]];
    bindings = If[$arguments === {}, "", "$library =\n" <> ToString[$libraryFile, InputForm] <> ";\n\n\n"] <>
        StringRiffle[generateBinding /@ definitions, "\n\n\n"];
    package = Import[$packageFile, "String"];
    output = insertBindings[StringReplace[package, "\r\n" -> "\n"], bindings];
    If[!DirectoryQ[DirectoryName[$libraryFile]],
        CreateDirectory[DirectoryName[$libraryFile], CreateIntermediateDirectories -> True]
    ];
    compiled = CreateLibrary[$sourceFiles, FileBaseName[$libraryFile],
        "TargetDirectory" -> DirectoryName[$libraryFile],
        "Debug" -> True,
        "TransferProtocolLibrary" -> Automatic,
        "ShellCommandFunction" -> Print,
        "ShellOutputFunction" -> Print,
        "SystemCompileOptions" -> $compileOptions,
        "IncludeDirectories" -> {$sourceDirectory}
    ];
    If[!StringQ[compiled] || !FileExistsQ[compiled], fail["Native library compilation failed."]];
    If[ExpandFileName[compiled] =!= $libraryFile,
        CopyFile[compiled, $libraryFile, OverwriteTarget -> True]
    ];
    If[Export[$packageFile, output, "Text"] === $Failed, fail["Cannot write bindings target."]];
    Print["Library: ", compiled];
    Print["Bindings: ", $packageFile];
];


If[!TrueQ[$buildDefinitionsOnly],
    With[{result = Catch[build[]]},
        If[FailureQ[result], Print[result]; Exit[1]];
    ];
];
