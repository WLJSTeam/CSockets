Needs["MUnit`"];


baseDir = DirectoryName[$InputFileName, 2];


Get[
    FileNameJoin[{baseDir, "Kernel", "CSockets.wl"}]
];


SocketSendTest::native =
"Injected failure after partial native send.";


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
                Block[{
                    calls = {},
                    WLJS`CSockets`Private`socketSendRange = Function[{row, bytes, offset, length},
                        AppendTo[
                            calls,
                            Normal[bytes]
                        ];
                        Length[bytes]
                    ]
                },
                    {
                        BinaryWrite[
                            CSocketObject[42],
                            ByteArray[{1, 2, 3, 4, 5}]
                        ],
                        calls
                    }
                ],
                {
                    5,
                    {
                        {1, 2, 3, 4, 5}
                    }
                },
                TestID -> "binary-write-passes-full-byte-array-to-native"
            ],
            VerificationTest[
                Block[{
                    calls = {},
                    WLJS`CSockets`Private`socketSendRange = Function[{row, bytes, offset, length},
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
                TestID -> "write-string-passes-complete-utf8-to-native"
            ],
            VerificationTest[
                Block[{
                    calls = {},
                    WLJS`CSockets`Private`socketSendRange = Function[{row, bytes, offset, length},
                        AppendTo[
                            calls,
                            Normal[bytes]
                        ];
                        Length[bytes]
                    ]
                },
                    {
                        WriteString[
                            CSocketObject[42],
                            FromCharacterCode[{97, 0, 98}]
                        ],
                        calls
                    }
                ],
                {
                    3,
                    {
                        {97, 0, 98}
                    }
                },
                TestID -> "write-string-preserves-embedded-null"
            ],
            VerificationTest[
                Table[
                    Block[{
                        calls = 0,
                        WLJS`CSockets`Private`socketSendRange = Function[{socketId, bytes, offset, length},
                            calls++;
                            failure
                        ]
                    },
                        {Quiet[BinaryWrite[CSocketObject[42], ByteArray[{1, 2, 3}]]], calls}
                    ],
                    {failure, {1, 0, LibraryFunctionError["send", 6]}}
                ],
                Table[
                    {Failure["socketSend", <|
                        "SocketID" -> 42, "Host" -> "", "Port" -> 0, "BytesSent" -> sent, "BytesRequested" -> 3
                    |>], 1},
                    {sent, {1, 0, 0}}
                ],
                TestID -> "incomplete-native-send-reports-progress-without-wl-retry"
            ],
            VerificationTest[
                Block[{
                    WLJS`CSockets`Private`socketSendRange = Function[{socketId, bytes, offset, length},
                        Message[SocketSendTest::native];
                        1
                    ]
                },
                    BinaryWrite[CSocketObject[42], ByteArray[{1, 2, 3}]]
                ],
                Failure["socketSend", <|
                    "SocketID" -> 42, "Host" -> "", "Port" -> 0, "BytesSent" -> 1, "BytesRequested" -> 3
                |>],
                {SocketSendTest::native, WLJS`CSockets`Private`write::fail},
                TestID -> "native-send-message-retains-partial-byte-count"
            ],
            VerificationTest[
                Block[{
                    calls = {},
                    WLJS`CSockets`$CSockets = <|
                        42 -> <|
                            "Protocol" -> "UDP",
                            "Role" -> "Bound"
                        |>
                    |>,
                    WLJS`CSockets`Private`socketSendToRange = Function[{row, host, port, bytes, offset, length},
                        AppendTo[
                            calls,
                            {host <> ":" <> port, Normal[bytes]}
                        ];
                        2
                    ]
                },
                    {
                        BinaryWrite[
                            CSocketObject[42],
                            "127.0.0.1:9000",
                            ByteArray[{1, 2, 3}]
                        ],
                        calls
                    }
                ],
                {
                    Failure["socketSendTo", <|
                        "SocketID" -> 42, "Host" -> "127.0.0.1", "Port" -> 9000,
                        "BytesSent" -> 2, "BytesRequested" -> 3
                    |>],
                    {{"127.0.0.1:9000", {1, 2, 3}}}
                },
                {WLJS`CSockets`Private`write::fail},
                TestID -> "short-udp-write-keeps-datagram-in-one-native-call"
            ],
            VerificationTest[
                Block[{
                    calls = {},
                    WLJS`CSockets`$CSockets = <|
                        42 -> <|
                            "Protocol" -> "UDP",
                            "Role" -> "Bound"
                        |>
                    |>,
                    WLJS`CSockets`Private`socketSendToRange = Function[{row, host, port, bytes, offset, length},
                        AppendTo[
                            calls,
                            {host <> ":" <> port, Normal[bytes]}
                        ];
                        Length[bytes]
                    ]
                },
                    {
                        WriteString[
                            CSocketObject[42],
                            "127.0.0.1:9000",
                            FromCharacterCode[233]
                        ],
                        calls
                    }
                ],
                {
                    2,
                    {
                        {"127.0.0.1:9000", {195, 169}}
                    }
                },
                TestID -> "udp-write-string-sends-utf8-in-one-native-call"
            ],
            VerificationTest[
                Block[{
                    WLJS`CSockets`Private`socketSendRange = Function[{row, bytes, offset, length},
                        Length[bytes]
                    ]
                },
                    BinaryWrite[
                        CSocketObject[42],
                        ByteArray[{}]
                    ]
                ],
                0,
                TestID -> "empty-send-completes-with-zero"
            ]
        }
    ]
]
