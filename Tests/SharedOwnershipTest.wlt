Needs["MUnit`"];
Needs["CCompilerDriver`"];
baseDir = DirectoryName[$InputFileName, 2];
Get[FileNameJoin[{baseDir, "Kernel", "CSockets.wl"}]];
probeLibrary = CreateLibrary[
    {FileNameJoin[{baseDir, "Tests", "OwnershipProbe.c"}]},
    "csockets_ownership_probe",
    "TargetDirectory" -> $TemporaryDirectory
];
tensorShares = LibraryFunctionLoad[probeLibrary, "tensorShares", {{Integer, 1, "Shared"}}, Integer];
arrayShares = LibraryFunctionLoad[probeLibrary, "arrayShares", {{"ByteArray", "Shared"}}, Integer];
retainTensor = LibraryFunctionLoad[probeLibrary, "retainTensor", {{Integer, 1, "Shared"}}, "Void"];


TestReport[{
    VerificationTest[
        With[{server = CSocketOpen["127.0.0.1", 0]},
            With[{row = First[server]},
                Module[{before = tensorShares[row], result},
                    Do[
                        WLJS`CSockets`Private`socketGetPort[row];
                        WLJS`CSockets`Private`socketGetHost[row];
                        WLJS`CSockets`Private`socketSetNonBlockingMode[row];
                        WLJS`CSockets`Private`socketSetBlockingMode[row];
                        Quiet[WLJS`CSockets`Private`socketBind[row, ByteArray[{}]]],
                        {50}
                    ];
                    result = tensorShares[row] === before && row[[6]] === 0;
                    Close[server];
                    result && row[[5]] === 0
                ]
            ]
        ],
        True,
        TestID -> "ordinary-calls-release-shares-and-preserve-identity"
    ],
    VerificationTest[
        With[{server = CSocketOpen["127.0.0.1", 0, "UDP"], bytes = ByteArray[{1, 2, 3}]},
            With[{row = First[server]},
                Module[{before = {tensorShares[row], arrayShares[bytes]}, result},
                    Do[
                        Quiet[WLJS`CSockets`Private`socketSendTo[row, "invalid", 1, bytes, Length[bytes]]];
                        Quiet[WLJS`CSockets`Private`socketSendToAddressStorage[row, ByteArray[{}], bytes]],
                        {50}
                    ];
                    result = {tensorShares[row], arrayShares[bytes]} === before;
                    Close[server];
                    result
                ]
            ]
        ],
        True,
        TestID -> "error-paths-release-socket-and-byte-array-shares"
    ],
    VerificationTest[
        With[{server = CSocketOpen["127.0.0.1", 0]},
            With[{row = First[server]},
                retainTensor[row];
                retainTensor[row];
                Close[server];
                tensorShares[row] === 1 && row[[5]] === 0
            ]
        ],
        True,
        TestID -> "close-releases-all-retained-shares"
    ]
}]
