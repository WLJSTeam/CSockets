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
            Module[{id, result},
                id = createSocket["IPv4", "UDP"];
                result = Catch[
                    toNonBlocking[id]
                ] === Null && $CSockets[id, "BlockingMode"] === "NonBlocking";
                result = result && Catch[
                    toBlocking[id]
                ] === Null && $CSockets[id, "BlockingMode"] === "Blocking";
                close[id];
                result
            ],
            True,
            TestID -> "successful-mode-changes-update-metadata"
        ],
        VerificationTest[
            Module[{
                id,
                before,
                nativeFailures,
                nonblockingFailure,
                blockingFailure,
                result
            },
                id = createSocket["IPv4", "UDP"];
                before = $CSockets[id];
                socketClose[id];
                nativeFailures = Quiet[
                    {socketSetNonBlockingMode[id], socketSetBlockingMode[id]}
                ];
                nonblockingFailure = Quiet[
                    Catch[
                        toNonBlocking[id]
                    ]
                ];
                result = AllTrue[
                    nativeFailures,
                    MatchQ[#, _LibraryFunctionError]&
                ] && nonblockingFailure === $Failed && $CSockets[id] === before;
                $CSockets[id, "BlockingMode"] = "NonBlocking";
                before = $CSockets[id];
                blockingFailure = Quiet[
                    Catch[
                        toBlocking[id]
                    ]
                ];
                result = result && blockingFailure === $Failed && $CSockets[id] === before;
                unregisterSocket[id];
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
