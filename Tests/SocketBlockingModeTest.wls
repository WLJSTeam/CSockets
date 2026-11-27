Needs["MUnit`"];


Get[
    FileNameJoin[
        {DirectoryName[$InputFileName, 2], "Kernel", "CSockets.wl"}
    ]
];


Begin["WLJS`CSockets`Private`"];


report = TestReport[
    {
        VerificationTest[
            Module[{socketId, result},
                socketId = createSocket["IPv4", "UDP"];
                result = Catch[
                    toNonBlocking[socketId]
                ] === Null && $CSockets[socketId, "BlockingMode"] === "NonBlocking";
                result = result && Catch[
                    toBlocking[socketId]
                ] === Null && $CSockets[socketId, "BlockingMode"] === "Blocking";
                close[socketId];
                result
            ],
            True,
            TestID -> "successful-mode-changes-update-metadata"
        ],
        VerificationTest[
            Module[{
                socketId,
                before,
                nativeFailures,
                nonblockingFailure,
                blockingFailure,
                result
            },
                socketId = createSocket["IPv4", "UDP"];
                before = $CSockets[socketId];
                socketClose[socketId];
                nativeFailures = Quiet[
                    {socketSetNonBlockingMode[socketId], socketSetBlockingMode[socketId]}
                ];
                nonblockingFailure = Quiet[
                    Catch[
                        toNonBlocking[socketId]
                    ]
                ];
                result = AllTrue[
                    nativeFailures,
                    MatchQ[#, _LibraryFunctionError]&
                ] && nonblockingFailure === Failure["socketSetNonBlockingMode", <|"SocketID" -> socketId|>] && $CSockets[socketId] === before;
                $CSockets[socketId, "BlockingMode"] = "NonBlocking";
                before = $CSockets[socketId];
                blockingFailure = Quiet[
                    Catch[
                        toBlocking[socketId]
                    ]
                ];
                result = result && blockingFailure === Failure["socketSetBlockingMode", <|"SocketID" -> socketId|>] && $CSockets[socketId] === before;
                unregisterSocket[socketId];
                result
            ],
            True,
            TestID -> "closed-descriptor-failures-throw-without-mutating-metadata"
        ],
        VerificationTest[
            AllTrue[
                Quiet[
                    {socketSetNonBlockingMode[-1], socketSetBlockingMode[-1]}
                ],
                MatchQ[#, _LibraryFunctionError]&
            ],
            True,
            TestID -> "invalid-descriptor-is-rejected-by-both-native-setters"
        ]
    }
];


Print[
    "Passed: ",
    report["TestsSucceededCount"],
    "; failed: ",
    report["TestsFailedCount"]
];


If[report["TestsFailedCount"] > 0,
    Print[
        report["TestsFailed"]
    ];
    Exit[1]
];


End[];
