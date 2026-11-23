Needs["CCompilerDriver`"];


$conversionRoot = DirectoryName[$InputFileName, 2];
$conversionLibrary = CreateLibrary[
    {
        FileNameJoin[{$conversionRoot, "Tests", "ArrayConversionProbe.c"}],
        FileNameJoin[{$conversionRoot, "Source", "common.c"}]
    },
    "array_conversion_probe",
    "TargetDirectory" -> $TemporaryDirectory,
    "IncludeDirectories" -> {FileNameJoin[{$conversionRoot, "Source"}]}
];


$copyBytes = LibraryFunctionLoad[$conversionLibrary, "copyBytes", {{"ByteArray", "Automatic"}}, "ByteArray"];
$copySockets = LibraryFunctionLoad[$conversionLibrary, "copySockets", {{Integer, 1}}, {Integer, 1}];


TestReport[{
    VerificationTest[Normal[$copyBytes[ByteArray[{0, 1, 127, 128, 255}]]],
        {0, 1, 127, 128, 255}, TestID -> "byte-copy-survives-source-mutation"],
    VerificationTest[Normal[$copyBytes[ByteArray[{}]]], {}, TestID -> "empty-byte-vector"],
    VerificationTest[$copySockets[{0, 1, 2147483647}], {0, 1, 2147483647}, TestID -> "socket-vector-round-trip"],
    VerificationTest[$copySockets[{}], {}, TestID -> "empty-socket-vector"]
}]
