$buildDefinitionsOnly = True;
Get[FileNameJoin[{DirectoryName[$InputFileName, 2], "Build.wls"}]];


$sample = "/* DLLEXPORT int fake() {} */\nDLLEXPORT /* { */ int example(\nWolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res) {\nconst char *text = \"} /*\"; char ch = '}';\nmint second_arg = (mint) MArgument_getInteger(\nArgs [ 1 ]);\nmint first_arg\n= MArgument_getInteger(Args[0]);\nif (1) { /* } */ }\nMArgument_setInteger(\nRes, second_arg);\n} ";
$definition = First[getFunctionDefinitions[$sample]];


$report = TestReport[{
    VerificationTest[Length[getFunctionDefinitions[$sample]], 1, TestID -> "comments and literals"],
    VerificationTest[getFunctionName[$definition], "example", TestID -> "multiline signature"],
    VerificationTest[getArgumentNames[$definition], {"firstArg", "secondArg"}, TestID -> "argument index order"],
    VerificationTest[getArgumentTypes[$definition], {Integer, Integer}, TestID -> "multiline getters"],
    VerificationTest[getReturnType[$definition], Integer, TestID -> "return type"],
    VerificationTest[getResultName[$definition], "secondArg", TestID -> "multiline setter"],
    VerificationTest[getFunctionDefinition[$sample, "example"],
        StringTrim[StringDrop[$sample, First[First[StringPosition[$sample, "DLLEXPORT /*"]]] - 1]],
        TestID -> "original source preserved"],
    VerificationTest[insertBindings["Begin[\"x`\"];\nEnd[];\nEndPackage[];", "binding"],
        "Begin[\"x`\"];\n(* :LibraryLoad: *)\n\n\nbinding\n\n\nEnd[];\nEndPackage[];", TestID -> "insert missing marker"],
    VerificationTest[insertBindings["(* :LibraryLoad: *)old\nEnd[];\nEndPackage[];", "new"],
        "(* :LibraryLoad: *)\n\n\nnew\n\n\nEnd[];\nEndPackage[];", TestID -> "replace existing bindings"],
    VerificationTest[insertBindings["x = \"End[];\"; (* End[]; (* nested *) *) End[];", "new"],
        "x = \"End[];\"; (* End[]; (* nested *) *) (* :LibraryLoad: *)\n\n\nnew\n\n\nEnd[];", TestID -> "ignore quoted and commented End"],
    VerificationTest[getReturnType[cTokens["DLLEXPORT int f() { libData->MTensor_new(MType_Integer, 2, dims, &tensor); MArgument_setMTensor(Res, tensor); }"]],
        {Integer, 2}, TestID -> "tensor rank"],
    VerificationTest[getResultName[cTokens["DLLEXPORT int f() { MArgument_setBoolean(Res, call(a, b) == 0); }"]],
        "", TestID -> "expression has no result variable"],
    VerificationTest[
        StringContainsQ[
            generateBinding[cTokens[getFunctionDefinition[
                Import[FileNameJoin[{$sourceDirectory, "socket.c"}], "String"], "socketConnectedQ"
            ]]],
            "socketConnectedQ[socketId] -> True | False."
        ],
        True, TestID -> "Boolean expression usage includes return type"
    ],
    VerificationTest[
        StringContainsQ[generateBinding[cTokens["DLLEXPORT int f() { MArgument_setInteger(Res, a + b); }"]],
            "f[] -> Integer."],
        True, TestID -> "unnamed result usage includes return type"
    ],
    VerificationTest[
        StringContainsQ[generateBinding[cTokens["DLLEXPORT int f() { return 0; }"]], "f[]."],
        True, TestID -> "Void usage has no result"
    ],
    VerificationTest[FailureQ[Catch[insertBindings["Begin[\"x`\"];", "new"]]], True, TestID -> "reject missing End"],
    VerificationTest[FailureQ[Catch[getReturnType[cTokens["DLLEXPORT int f() { MArgument_setByteArray(Res, result); }"]]]],
        True, TestID -> "reject custom ByteArray setter"],
    VerificationTest[FailureQ[Catch[getArgumentTypes[cTokens["DLLEXPORT int f() { BYTE *data = MArgument_getByteArray(Args[0]); }"]]]],
        True, TestID -> "reject custom ByteArray getter"],
    VerificationTest[getReturnType[cTokens["DLLEXPORT int f() { MTensor tensor = MTensorFromSocket(libData, sockets, count); MArgument_setMTensor(Res, tensor); }"]],
        {Integer, 1}, TestID -> "socket conversion result rank"],
    VerificationTest[FailureQ[Catch[getReturnType[cTokens["DLLEXPORT int f() { MArgument_setUnknown(Res, result); }"]]]],
        True, TestID -> "reject unknown types"]
}];
Print["Passed: ", $report["TestsSucceededCount"], "; failed: ", $report["TestsFailedCount"]];
If[$report["TestsFailedCount"] > 0, Exit[1]];
