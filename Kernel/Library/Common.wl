(* ::Package:: *)

BeginPackage["WLJS`CSockets`Library`Common`", {
    "CCompilerDriver`",
    "LibraryLink`"
}];


$CSocketsLibrary::usage =
"$CSocketsLibrary";


Begin["`Private`"];


$directory =
DirectoryName[$InputFileName, 3];


$libraryLinkVersion =
LibraryVersionInformation[FindLibrary["demo"]]["WolframLibraryVersion"];


$CSocketsLibrary = FileNameJoin[{
    $directory,
    "LibraryResources",
    $SystemID <> "-v" <> ToString[$libraryLinkVersion],
    "csockets." <> Internal`DynamicLibraryExtension[]
}];


End[];


EndPackage[];