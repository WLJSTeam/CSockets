Needs["MUnit`"];


baseDir = DirectoryName[$InputFileName, 2];


Get[
    FileNameJoin[{baseDir, "Kernel", "CSockets.wl"}]
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
                Block[{
                    calls = {},
                    WLJS`CSockets`Private`socketSend = Function[{row, bytes},
                        AppendTo[
                            calls,
                            Normal[bytes]
                        ];
                        Min[
                            2,
                            Length[bytes]
                        ]
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
                        {1, 2, 3, 4, 5},
                        {3, 4, 5},
                        {5}
                    }
                },
                TestID -> "binary-write-recursively-sends-remainder"
            ],
            VerificationTest[
                Block[{
                    calls = {},
                    WLJS`CSockets`Private`socketSend = Function[{row, bytes},
                        AppendTo[
                            calls,
                            Normal[bytes]
                        ];
                        Min[
                            1,
                            Length[bytes]
                        ]
                    ]
                },
                    {WriteString[CSocketObject[42], FromCharacterCode[233]], calls}
                ],
                {
                    2,
                    {
                        {195, 169},
                        {169}
                    }
                },
                TestID -> "write-string-resumes-inside-utf8-character"
            ],
            VerificationTest[
                Block[{
                    calls = {},
                    WLJS`CSockets`Private`socketSend = Function[{row, bytes},
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
                        WLJS`CSockets`Private`socketSend = Function[{row, bytes},
                            calls++;
                            If[calls === 1,
                                1,
                                failure
                            ]
                        ]
                    },
                        {
                            Quiet[
                                BinaryWrite[
                                    CSocketObject[42],
                                    ByteArray[{1, 2, 3}]
                                ]
                            ],
                            calls
                        }
                    ],
                    {
                        failure,
                        {0, LibraryFunctionError["send", 6]}
                    }
                ],
                ConstantArray[{
                    Failure["socketSend", <|
                        "SocketID" -> 42, "Host" -> "", "Port" -> 0, "BytesSent" -> 1, "BytesRequested" -> 3
                    |>],
                    2
                }, 2],
                TestID -> "send-stops-on-zero-progress-or-error"
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
                    WLJS`CSockets`Private`socketSendTo = Function[{row, host, port, bytes},
                        AppendTo[
                            calls,
                            {host <> ":" <> port, Normal[bytes]}
                        ];
                        Min[
                            2,
                            Length[bytes]
                        ]
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
                    3,
                    {
                        {
                            "127.0.0.1:9000",
                            {1, 2, 3}
                        },
                        {
                            "127.0.0.1:9000",
                            {3}
                        }
                    }
                },
                TestID -> "udp-binary-write-resends-remainder-to-same-address"
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
                    WLJS`CSockets`Private`socketSendTo = Function[{row, host, port, bytes},
                        AppendTo[
                            calls,
                            {host <> ":" <> port, Normal[bytes]}
                        ];
                        Min[
                            1,
                            Length[bytes]
                        ]
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
                        {
                            "127.0.0.1:9000",
                            {195, 169}
                        },
                        {
                            "127.0.0.1:9000",
                            {169}
                        }
                    }
                },
                TestID -> "udp-write-string-converts-utf8-and-resends-remainder"
            ],
            VerificationTest[
                Block[{
                    WLJS`CSockets`Private`socketSend = Function[{row, bytes},
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
