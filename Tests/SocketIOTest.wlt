Needs["MUnit`"];


Get[
    FileNameJoin[
        {DirectoryName[$InputFileName, 2], "Kernel", "CSockets.wl"}
    ]
];


Block[{
    WLJS`CSockets`$CSockets = <|
        42 -> <|
            "Protocol" -> "TCP",
            "Role" -> "Connected"
        |>
    |>
},
    TestReport[
        {
            VerificationTest[
                Map[
                    Function[pair,
                        Block[{
                            WLJS`CSockets`$CSockets = <|
                                42 -> <|
                                    "Protocol" -> pair[[1]],
                                    "Role" -> pair[[2]],
                                    "Buffer" -> ByteArray[{0}]
                                |>
                            |>,
                            WLJS`CSockets`Private`socketRecv = Function[{socketId, buffer},
                                ByteArray[{97}]
                            ],
                            WLJS`CSockets`Private`socketRecvFrom = Function[Null,
                                Throw["unexpected recvfrom"]
                            ],
                            WLJS`CSockets`Private`socketSendRange = Function[{socketId, bytes, offset, length},
                                Length[bytes]
                            ],
                            WLJS`CSockets`Private`socketSendToRange = Function[Null,
                                Throw["unexpected sendto"]
                            ]
                        },
                            {
                                ReadByteArray[
                                    CSocketObject[42]
                                ],
                                ReadString[
                                    CSocketObject[42]
                                ],
                                SocketReadMessage[
                                    CSocketObject[42]
                                ],
                                WriteString[
                                    CSocketObject[42],
                                    "a"
                                ],
                                Quiet[
                                    WriteString[
                                        CSocketObject[42],
                                        "127.0.0.1:9000",
                                        "a"
                                    ]
                                ]
                            }
                        ]
                    ],
                    {
                        {"UDP", "Connected"},
                        {"TCP", "Connected"},
                        {"TCP", "Accepted"}
                    }
                ],
                ConstantArray[
                    {
                        ByteArray[{97}],
                        "a",
                        ByteArray[{97}],
                        1,
                        Failure["write", <|"SocketID" -> 42, "Host" -> "127.0.0.1", "Port" -> 9000|>]
                    },
                    3
                ],
                TestID -> "connected-and-accepted-use-recv-and-send"
            ],
            VerificationTest[
                Block[{
                    WLJS`CSockets`$CSockets = <|
                        42 -> <|
                            "Protocol" -> "UDP",
                            "Role" -> "Bound"
                        |>
                    |>,
                    WLJS`CSockets`Private`socketSendRange = Function[Null,
                        Throw["unexpected send"]
                    ]
                },
                    Quiet[
                        BinaryWrite[
                            CSocketObject[42],
                            ByteArray[{97}]
                        ]
                    ]
                ],
                Failure["write", <|"SocketID" -> 42, "Host" -> "", "Port" -> 0|>],
                TestID -> "bound-udp-requires-destination"
            ],
            VerificationTest[
                Block[{
                    WLJS`CSockets`$CSockets = <||>,
                    WLJS`CSockets`Private`socketRecv = Function[{socketId, buffer},
                        buffer
                    ]
                },
                    WLJS`CSockets`Private`registerSocket[41];
                    WLJS`CSockets`Private`registerSocket[42];
                    With[{sizes = Length /@ Lookup[Values[$CSockets], "Buffer"]},
                        $CSockets[41, "Buffer"] = ByteArray[{1}];
                        $CSockets[42, "Buffer"] = ByteArray[{2}];
                        {
                            sizes,
                            Normal /@ {
                                ReadByteArray[
                                    CSocketObject[41]
                                ],
                                ReadByteArray[
                                    CSocketObject[42]
                                ],
                                ReadByteArray[
                                    CSocketObject[41]
                                ]
                            }
                        }
                    ]
                ],
                {
                    {65536, 65536},
                    {
                        {1},
                        {2},
                        {1}
                    }
                },
                TestID -> "read-uses-registered-socket-buffer"
            ],
            VerificationTest[
                Block[{
                    calls = {},
                    WLJS`CSockets`Private`socketSendRange = Function[{socketId, bytes, offset, length},
                        AppendTo[
                            calls,
                            Normal[bytes]
                        ];
                        Length[bytes]
                    ]
                },
                    {BinaryWrite[CSocketObject[42], ByteArray[Range[5]]], calls}
                ],
                {
                    5,
                    {
                        {1, 2, 3, 4, 5}
                    }
                },
                TestID -> "stream-write-delegates-full-payload"
            ],
            VerificationTest[
                Block[{
                    calls = {},
                    WLJS`CSockets`Private`socketSendRange = Function[{socketId, bytes, offset, length},
                        AppendTo[
                            calls,
                            Normal[bytes]
                        ];
                        Length[bytes]
                    ]
                },
                    {WriteString[CSocketObject[42], FromCharacterCode[233]], calls}
                ],
                {
                    2,
                    {
                        {195, 169}
                    }
                },
                TestID -> "utf8-write-delegates-full-payload"
            ],
            VerificationTest[
                Block[{
                    WLJS`CSockets`Private`socketSendRange = Function[{socketId, bytes, offset, length},
                        0
                    ]
                },
                    {
                        BinaryWrite[
                            CSocketObject[42],
                            ByteArray[{}]
                        ],
                        Quiet[
                            BinaryWrite[
                                CSocketObject[42],
                                ByteArray[{1}]
                            ]
                        ]
                    }
                ],
                {0, Failure["socketSend", <|"SocketID" -> 42, "Host" -> "", "Port" -> 0, "BytesSent" -> 0, "BytesRequested" -> 1|>]},
                TestID -> "empty-write-and-zero-progress"
            ],
            VerificationTest[
                Block[{
                    WLJS`CSockets`$CSockets = <|
                        42 -> <|
                            "Protocol" -> "UDP",
                            "Role" -> "Bound"
                        |>
                    |>,
                    WLJS`CSockets`Private`socketSendToRange = Function[{socketId, host, port, bytes, offset, length},
                        If[{host, port, Normal[bytes]} === {
                                "127.0.0.1",
                                "9000",
                                {97}
                            },
                            1,
                            -1
                        ]
                    ]
                },
                    WriteString[
                        CSocketObject[42],
                        "127.0.0.1:9000",
                        "a"
                    ]
                ],
                1,
                TestID -> "addressed-write-uses-association-fields"
            ],
            VerificationTest[
                Block[{
                    WLJS`CSockets`$CSockets = <|
                        42 -> <|
                            "Protocol" -> "TCP",
                            "Buffer" -> ByteArray[{0}]
                        |>
                    |>,
                    WLJS`CSockets`Private`socketRecv = Function[{socketId, buffer},
                        ByteArray[{97}]
                    ]
                },
                    {
                        ReadByteArray[
                            CSocketObject[42]
                        ],
                        ReadString[
                            CSocketObject[42]
                        ],
                        SocketReadMessage[
                            CSocketObject[42]
                        ]
                    }
                ],
                {
                    ByteArray[{97}],
                    "a",
                    ByteArray[{97}]
                },
                TestID -> "stream-read-overrides"
            ],
            VerificationTest[
                Block[{
                    WLJS`CSockets`$CSockets = <|
                        42 -> <|
                            "Protocol" -> "UDP",
                            "Role" -> "Bound",
                            "Buffer" -> ByteArray[{0}]
                        |>
                    |>,
                    WLJS`CSockets`Private`socketRecvFrom = Function[{socketId, buffer},
                        Developer`DataStore[
                            "127.0.0.1:9000",
                            NumericArray[{97}, "UnsignedInteger8"]
                        ]
                    ]
                },
                    {ReadByteArray[CSocketObject[42]], ReadString[CSocketObject[42]]}
                ],
                {
                    {
                        "127.0.0.1:9000",
                        ByteArray[{97}]
                    },
                    {"127.0.0.1:9000", "a"}
                },
                TestID -> "datagram-read-preserves-address"
            ],
            VerificationTest[
                Block[{
                    WLJS`CSockets`$CSockets = <|
                        42 -> <|
                            "Protocol" -> "UDP",
                            "Role" -> "Bound",
                            "Buffer" -> ByteArray[{0}]
                        |>
                    |>,
                    WLJS`CSockets`Private`socketRecvFrom = Function[{socketId, buffer},
                        Developer`DataStore["127.0.0.1:9000"]
                    ]
                },
                    ReadString[
                        CSocketObject[42]
                    ]
                ],
                {"127.0.0.1:9000", ""},
                TestID -> "empty-datagram-read"
            ],
            VerificationTest[
                Block[{
                    WLJS`CSockets`$CSockets = <|
                        42 -> <|
                            "Protocol" -> "TCP",
                            "Buffer" -> ByteArray[{0}]
                        |>
                    |>,
                    WLJS`CSockets`Private`socketRecv = Function[{socketId, buffer},
                        $Failed
                    ]
                },
                    Quiet[
                        ReadString[
                            CSocketObject[42]
                        ]
                    ]
                ],
                Failure["socketRecv", <|"SocketID" -> 42|>],
                TestID -> "read-failure-propagates"
            ]
        }
    ]
]
