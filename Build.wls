#!/usr/bin/env wolframscript

Get["CCompilerDriver`"];
Get["LibraryLink`"];


$libraryLinkVersion = 
LibraryVersionInformation[FindLibrary["demo"]]["WolframLibraryVersion"];


build[lib_String, prot_: Automatic] := Block[{$directory, $libSrcs, $libSrcDir, $libDir, $linkerOptions},
    $directory = DirectoryName[If[$InputFileName == "",
        NotebookFileName[],
        $InputFileName
    ], 1];

    $libSrcDir = FileNameJoin[{$directory, "Source"}];

    $libSrcs = FileNames["*.c", {$libSrcDir}]; 

    $libDir = FileNameJoin[{
        $directory, 
        "LibraryResources", 
        $SystemID <> "-v" <> ToString[$libraryLinkVersion]
    }]; 

    If[!FileExistsQ[$libDir], CreateDirectory[]];

    CreateLibrary @@ {$libSrcs, lib,
        "TargetDirectory" -> $libDir,
        "Debug" -> True,
        If[prot === Automatic, Nothing, "TransferProtocolLibrary" -> "WSTP"],
        "ShellCommandFunction" -> Print,
        "ShellOutputFunction" -> Print,
        "SystemCompileOptions" -> "/Ox /GL", 
        "IncludeDirectories" -> {$libSrcDir}
    }
];


build["csockets"];