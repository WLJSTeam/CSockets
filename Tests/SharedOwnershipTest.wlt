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
                before,
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
                Scan[Close, {client, server}];
                result
            ],
            True,
            TestID -> "descriptor-send-releases-byte-array-share-on-success"
        ]
    }
]
