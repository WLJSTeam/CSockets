(* ::Package:: *)

BeginPackage["WLJS`CSockets`Library`Buffer`", {
    "WLJS`CSockets`Library`Common`",
    "CCompilerDriver`",
    "LibraryLink`"
}];


socketBufferCreate::usage =
"socketBufferCreate[bufferSize] returns buffer pointer.";


socketBufferRemove::usage =
"socketBufferRemove[bufferPointer] free buffer.";


Begin["`Private`"];


socketBufferCreate =
LibraryFunctionLoad[$CSocketsLibrary, "socketBufferCreate", {Integer}, Integer];


socketBufferRemove =
LibraryFunctionLoad[$CSocketsLibrary, "socketBufferRemove", {Integer}, "Void"];


End[];


EndPackage[];