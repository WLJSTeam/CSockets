Needs["MUnit`"];


Get[
    FileNameJoin[
        {DirectoryName[$InputFileName, 2], "Kernel", "CSockets.wl"}
    ]
];


Begin["WLJS`CSockets`Private`"];


descriptorReport = TestReport[
    {
        VerificationTest[
            MatchQ[
                Quiet[
                    socketCreate[2, #]
                ],
                _LibraryFunctionError
            ]& /@ {0, -1, 1, 4294967302},
            {True, True, True, True},
            TestID -> "unsupported-protocols-are-rejected-without-integer-truncation"
        ],
        VerificationTest[
            And @@ Table[
                Module[{server, client, id, accepted, result},
                    server = CSocketOpen["127.0.0.1", 0];
                    client = CSocketConnect[
                        server["LocalAddress"]
                    ];
                    id = socketAccept[
                        First[server]
                    ];
                    registerAcceptedSocket[
                        First[server],
                        id
                    ];
                    accepted = CSocketObject[id];
                    If[nonblocking,
                        toNonBlocking[id]
                    ];
                    BinaryWrite[
                        client,
                        ByteArray[{1, 2, 3}]
                    ];
                    result = IntegerQ[id] && socketConnectedQ[id] && SocketReadyQ[accepted, 1] && SocketReadMessage[accepted] === ByteArray[{1, 2, 3}];
                    Close[client];
                    If[!nonblocking,
                        toNonBlocking[id]
                    ];
                    Do[
                        Pause[0.02];
                        If[!socketConnectionAliveQ[id],
                            Break[]
                        ],
                        {100}
                    ];
                    result = result && !socketConnectionAliveQ[id];
                    Scan[Close, {accepted, server}];
                    result
                ],
                {
                    nonblocking,
                    {False, True}
                }
            ],
            True,
            TestID -> "integer-descriptors-support-blocking-and-nonblocking-tcp"
        ],
        VerificationTest[
            Module[{receiver, sender, result, received},
                receiver = CSocketOpen["127.0.0.1", 0, "UDP"];
                sender = CSocketConnect[
                    receiver["LocalAddress"]
                ];
                toNonBlocking[
                    First[receiver]
                ];
                result = MatchQ[
                    Quiet[
                        socketRecvFrom[
                            First[receiver],
                            ByteArray[{0}]
                        ]
                    ],
                    _LibraryFunctionError
                ];
                toBlocking[
                    First[receiver]
                ];
                BinaryWrite[
                    sender,
                    ByteArray[{4, 5}]
                ];
                received = socketRecvFrom[
                    First[receiver],
                    ByteArray[{0, 0}]
                ];
                result = result && Normal[
                    Last[received]
                ] === {4, 5};
                Scan[Close, {sender, receiver}];
                result
            ],
            True,
            TestID -> "native-udp-mode-switching-and-data-store-layout"
        ],
        VerificationTest[
            socketConnectedQ[-1],
            False,
            TestID -> "invalid-descriptor-is-not-connected"
        ]
    }
];


End[];


WLJS`CSockets`Private`descriptorReport
