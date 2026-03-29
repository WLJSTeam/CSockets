(* ::Package:: *)

BeginPackage["WLJS`CSockets`Library`Async`", {
    "WLJS`CSockets`Library`Common`",
    "CCompilerDriver`",
    "LibraryLink`"
}];


socketsSelectAsync::usage =
"socketsSelectAsync[sockets, length, timeout] creates a thread where waits for sockets to be ready.
- sockets: built-in List with socket ids.";


Begin["`Private`"];


socketsSelectAsync =
LibraryFunctionLoad[$CSocketsLibrary, "socketsSelectAsync", {{Integer, 1}, Integer, Integer}, Integer];


End[];


EndPackage[];