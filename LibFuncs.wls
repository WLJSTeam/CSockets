#!/usr/bin/env wolframscript
(* ::Package:: *)

code = Import["C:\\Users\\Kirill\\Projects\\CSockets\\Source\\csockets.c", "String"]; 


funcs = StringCases[code, 
	Shortest["DLLEXPORT int " ~~ __ ~~ "(WolframLibraryData libData, " ~~ __ ~~ "\n}"]
]; 


getName[func_String] := First @ StringCases[func, 
	Shortest["DLLEXPORT int " ~~ name: LetterCharacter.. ~~ "(WolframLibraryData libData, "] ~~ __ :> name
];

getName[funcs[[-1]]]


getArgs[func_String] := StringCases[func, 
	Shortest[{" *", " "} ~~ (argName: LetterCharacter..) ~~ " = " ~~ __ ~~ "MArgument_get" ~~ argType__ ~~ "(Args[" ~~ argNum_ ~~ "])"] :> 
	{argName, argType, ToExpression[argNum] + 1}
];

getArgs[funcs[[-1]]]


getReturn[func_String] := StringCases[func, 
	Shortest["MArgument_set" ~~ returnType__ ~~ "(Res," ~~ resName__ ~~ ");"] :> 
	{returnType, resName}
];

getReturn[funcs[[-1]]]


Grid[Map[{getName[#], getArgs[#], getReturn[#]}&] @ funcs, Frame->All]
