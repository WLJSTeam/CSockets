Needs["MUnit`"];


Needs["CCompilerDriver`"];


baseDir = DirectoryName[$InputFileName, 2];


Get[
    FileNameJoin[{baseDir, "Kernel", "CSockets.wl"}]
];


probeLibrary = CreateLibrary[
    {
        FileNameJoin[{baseDir, "Tests", "OwnershipProbe.c"}]
    },
    "csockets_ownership_probe",
    "TargetDirectory" -> $TemporaryDirectory
];


arrayShares = LibraryFunctionLoad[probeLibrary, "arrayShares", {{"ByteArray", "Shared"}}, Integer];


TestReport[
    {
        VerificationTest[
            Module[{
                server,
                bytes = ByteArray[{1, 2, 3}],
                before,
                result
            },
                server = CSocketOpen["127.0.0.1", 0, "UDP"];
                before = arrayShares[bytes];
                Do[
                    Quiet[
                        WLJS`CSockets`Private`socketSendTo[
                            First[server],
                            "invalid",
                            "1",
                            bytes
                        ]
                    ];
                    Quiet[
                        WLJS`CSockets`Private`socketSendTo[
                            First[server],
                            "127.0.0.1",
                            "invalid",
                            bytes
                        ]
                    ],
                    {50}
                ];
                result = arrayShares[bytes] === before && IntegerQ[
                    First[server]
                ];
                Close[server];
                result
            ],
            True,
            TestID -> "descriptor-calls-release-byte-array-shares-on-errors"
        ],
        VerificationTest[
            Module[{
                server,
                client,
                bytes = ByteArray[{1, 2}],
                buffer = ByteArray[ConstantArray[0, 16]],
                before, bufferBefore,
                result
            },
                server = CSocketOpen["127.0.0.1", 0, "UDP"];
                client = CSocketConnect[
                    "127.0.0.1",
                    WLJS`CSockets`Private`splitAddress[
                        server["LocalAddress"]
                    ]["Port"],
                    "UDP",
                    "Wait" -> True
                ];
                before = arrayShares[bytes];
                result = BinaryWrite[client, bytes] === 2 && arrayShares[bytes] === before;
                result = result && Last[
                    SocketReadMessage[server]
                ] === bytes;
                bufferBefore = arrayShares[buffer];
                result = result &&
                    WLJS`CSockets`Private`socketSendRange[First[client], bytes, 1, 1] === 1 &&
                    TrueQ[SocketReadyQ[server, 1]] &&
                    MatchQ[List @@ WLJS`CSockets`Private`socketRecvFromInto[First[server], buffer], {1, _String}] &&
                    First[Normal[buffer]] === 2 &&
                    arrayShares[bytes] === before && arrayShares[buffer] === bufferBefore;
                Scan[Close, {client, server}];
                result
            ],
            True,
            TestID -> "send-and-receive-into-release-byte-array-shares-on-success"
        ]
    }
]
