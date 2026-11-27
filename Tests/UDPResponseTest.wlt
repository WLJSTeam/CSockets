Needs["MUnit`"];


baseDir = DirectoryName[$InputFileName, 2];


Get[
    FileNameJoin[{baseDir, "Kernel", "CSockets.wl"}]
];


TestReport[
    {
        VerificationTest[
            Block[{
                calls = {},
                WLJS`CSockets`$CSockets = <|
                    42 -> <|
                        "Protocol" -> "TCP",
                        "Role" -> "Connected"
                    |>
                |>,
                WLJS`CSockets`Private`socketSendRange = Function[{socketId, bytes, offset, length},
                    AppendTo[
                        calls,
                        {"TCP", Normal[bytes]}
                    ];
                    Length[bytes]
                ],
                WLJS`CSockets`Private`socketSendToRange = Function[{socketId, host, port, bytes, offset, length},
                    AppendTo[
                        calls,
                        {"UDP", host <> ":" <> port, Normal[bytes]}
                    ];
                    Length[bytes]
                ]
            },
                WLJS`CSockets`Private`sendResponse[
                    <|
                        "SourceSocket" -> CSocketObject[42],
                        "Result" -> "ok"
                    |>
                ];
                $CSockets[42, "Protocol"] = "UDP";
                $CSockets[42, "Role"] = "Bound";
                WLJS`CSockets`Private`sendResponse[
                    <|
                        "SourceSocket" -> CSocketObject[42],
                        "Address" -> "127.0.0.1:9000",
                        "Result" -> "ok"
                    |>
                ];
                WLJS`CSockets`Private`sendResponse[
                    <|
                        "SourceSocket" -> CSocketObject[42],
                        "Result" -> Null
                    |>
                ];
                calls
            ],
            {
                {
                    "TCP",
                    {111, 107}
                },
                {
                    "UDP",
                    "127.0.0.1:9000",
                    {111, 107}
                }
            },
            TestID -> "response-selects-send-path-by-address-field"
        ],
        VerificationTest[
            Module[{server, clients, task, handler, exchange, result, address},
                server = CSocketOpen["127.0.0.1", 0, "UDP"];
                clients = Table[
                    CSocketConnect[
                        "127.0.0.1",
                        WLJS`CSockets`Private`splitAddress[
                            server["LocalAddress"]
                        ]["Port"],
                        "UDP",
                        "Wait" -> True
                    ],
                    {2}
                ];
                handler = CSocketHandler[
                    "ReceivedFrom" -> (
                        Switch[First[
                                #["DataBytes"]
                            ],
                            1,
                            "Привет",
                            2,
                            ByteArray[{0, 128, 255}],
                            3,
                            ByteArray[{}],
                            4,
                            Null
                        ]&
                    )
                ];
                task = SocketListen[<|server -> handler|>];
                exchange[client_CSocketObject, request_Integer, expected_ByteArray] :=
                (
                    BinaryWrite[
                        client,
                        ByteArray[{request}]
                    ];
                    Do[
                        Pause[0.02];
                        If[TrueQ[
                                SocketReadyQ[client]
                            ],
                            Break[]
                        ],
                        {100}
                    ];
                    TrueQ[
                        SocketReadyQ[client]
                    ] && With[{received = SocketReadMessage[client]},
                        received === expected
                    ]
                );
                result = And[
                    exchange[
                        clients[[1]],
                        1,
                        StringToByteArray["Привет"]
                    ],
                    exchange[
                        clients[[2]],
                        2,
                        ByteArray[{0, 128, 255}]
                    ],
                    exchange[
                        clients[[1]],
                        3,
                        ByteArray[{}]
                    ],
                    !TrueQ[
                        SocketReadyQ[
                            clients[[2]]
                        ]
                    ]
                ];
                BinaryWrite[
                    clients[[2]],
                    ByteArray[{4}]
                ];
                Pause[0.15];
                result = result && !TrueQ[
                    SocketReadyQ[
                        clients[[2]]
                    ]
                ];
                address = "127.0.0.1:" <> ToString[
                    WLJS`CSockets`Private`splitAddress[
                        clients[[2]]["LocalAddress"]
                    ]["Port"]
                ];
                result = result && BinaryWrite[
                    server,
                    address,
                    ByteArray[{42}]
                ] === 1;
                result = result && TrueQ[
                    SocketReadyQ[
                        clients[[2]],
                        1
                    ]
                ] && With[{received = SocketReadMessage[clients[[2]]]},
                    received === ByteArray[{42}]
                ];
                RemoveAsynchronousTask[task];
                Pause[1.1];
                Scan[Close, clients];
                Close[server];
                result
            ],
            True,
            TestID -> "udp-handler-replies-to-each-sender-and-explicit-address"
        ],
        VerificationTest[
            Module[{server = CSocketOpen["127.0.0.1", 0, "UDP"], result},
                result = Quiet[
                    WLJS`CSockets`Private`socketSendTo[
                        First[server],
                        "invalid",
                        "80",
                        ByteArray[{42}]
                    ]
                ];
                Close[server];
                MatchQ[result, _LibraryFunctionError]
            ],
            True,
            TestID -> "udp-reply-rejects-invalid-numeric-host"
        ]
    }
]
