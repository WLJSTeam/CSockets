Needs["MUnit`"];


Get[
    FileNameJoin[
        {DirectoryName[$InputFileName, 2], "Kernel", "CSockets.wl"}
    ]
];


Begin["WLJS`CSockets`Private`"];


addressReport = TestReport[
    {
        VerificationTest[
            Module[{server, clients, received, result, payload},
                server = CSocketOpen["127.0.0.1", 0, "UDP"];
                clients = Table[
                    CSocketConnect[
                        server["LocalAddress"]
                    ],
                    {2}
                ];
                result = And @@ Table[
                    payload = If[i === 1,
                        ByteArray[
                            Range[7]
                        ],
                        ByteArray[{}]
                    ];
                    BinaryWrite[
                        clients[[i]],
                        payload
                    ];
                    If[!TrueQ[
                            SocketReadyQ[server, 1]
                        ],
                        False,
                        received = socketRecvFrom[
                            First[server],
                            ByteArray[
                                ConstantArray[0, 7]
                            ]
                        ];
                        Length[received] === If[i === 1,
                            2,
                            1
                        ] && First[received] === StringDrop[
                            clients[[i]]["LocalAddress"],
                            6
                        ] && If[i === 1,
                            ByteArray[
                                Last[received]
                            ] === payload,
                            True
                        ]
                    ],
                    {i, 2}
                ];
                Scan[
                    Close,
                    Append[clients, server]
                ];
                result
            ],
            True,
            TestID -> "native-recvfrom-returns-address-first-and-preserves-empty-datagrams"
        ],
        VerificationTest[
            Module[{server, client, result, received, reply},
                server = CSocketOpen["127.0.0.1", 0, "UDP"];
                client = CSocketConnect[
                    server["LocalAddress"]
                ];
                BinaryWrite[
                    client,
                    ByteArray[{1, 2, 3}]
                ];
                result = SocketReadyQ[server, 1];
                received = SocketReadMessage[server];
                result = result && received === {
                    StringDrop[
                        client["LocalAddress"],
                        6
                    ],
                    ByteArray[{1, 2, 3}]
                } && BinaryWrite[
                    server,
                    First[received],
                    Last[received]
                ] === 3 && SocketReadyQ[client, 1];
                reply = SocketReadMessage[client];
                result = result && reply === ByteArray[{1, 2, 3}];
                Scan[Close, {client, server}];
                result
            ],
            True,
            TestID -> "udp-wrapper-replies-to-native-sender-address"
        ],
        VerificationTest[
            Module[{server, result},
                server = CSocketOpen["127.0.0.1", 0, "UDP"];
                toNonBlocking[
                    First[server]
                ];
                result = Quiet[
                    socketRecvFrom[
                        First[server],
                        ByteArray[{0}]
                    ]
                ];
                Close[server];
                MatchQ[result, _LibraryFunctionError]
            ],
            True,
            TestID -> "recvfrom-without-data-reports-native-error"
        ],
        VerificationTest[
            Block[{$CSockets = <||>, socketRecvFrom},
                socketRecvFrom[socketId_Integer, buffer_ByteArray] :=
                Developer`DataStore[
                    "127.0.0.1:9000",
                    NumericArray[{1, 2}, "UnsignedInteger8"]
                ];
                registerSocket[42, "UDP", "Bound"];
                SocketReadMessage[
                    CSocketObject[42]
                ] === {
                    "127.0.0.1:9000",
                    ByteArray[{1, 2}]
                }
            ],
            True,
            TestID -> "bound-udp-wrapper-converts-native-data-store"
        ],
        VerificationTest[
            Module[{server, socketId, result},
                server = CSocketOpen["127.0.0.1", 0];
                socketId = First[server];
                result = KeyExistsQ[$CSockets, socketId];
                Close[server];
                result && !KeyExistsQ[$CSockets, socketId]
            ],
            True,
            TestID -> "closed-socket-is-removed-from-registry"
        ]
    }
];


End[];


WLJS`CSockets`Private`addressReport
