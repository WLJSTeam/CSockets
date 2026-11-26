Needs["MUnit`"];


baseDir = DirectoryName[$InputFileName, 2];


Get[
    FileNameJoin[{baseDir, "Kernel", "CSockets.wl"}]
];


Block[{
    WLJS`CSockets`$CSockets = <|
        42 -> <|
            "UUID" -> 42,
            "Protocol" -> "TCP",
            "Role" -> "Connected"
        |>
    |>
},
    TestReport[
        {
            VerificationTest[
                Block[{
                    sent = {},
                    logged = {},
                    WLJS`CSockets`$CSockets = <|
                        42 -> <|
                            "UUID" -> 42,
                            "Protocol" -> "UDP",
                            "Role" -> "Bound"
                        |>
                    |>,
                    WLJS`CSockets`Private`socketSendTo = Function[{row, host, port, bytes},
                        AppendTo[sent, {row, host <> ":" <> port, bytes}];
                        Length[bytes]
                    ]
                },
                    Module[{handler, packet, processed},
                        packet = <|
                            "Event" -> "ReceivedFrom",
                            "SourceSocket" -> CSocketObject[42],
                            "Address" -> "127.0.0.1:9000",
                            "DataByteArray" -> ByteArray[{0, 128, 255}]
                        |>;
                        handler = CSocketHandler[
                            "ReceivedFrom" -> Function[p,
                                p["DataByteArray"]
                            ],
                            "Logger" -> Function[p,
                                AppendTo[logged, p]
                            ]
                        ];
                        processed = handler[packet];
                        KeySort[processed] === KeySort[
                            Join[
                                packet,
                                <|
                                    "Handler" -> handler,
                                    "Result" -> packet["DataByteArray"],
                                    "Data" -> packet["DataByteArray"],
                                    "DataBytes" -> {0, 128, 255},
                                    "BufferKey" -> {42, packet["Address"]},
                                    "Completed" -> True,
                                    "ExpectedLength" -> 3,
                                    "StoredLength" -> 3,
                                    "DataLength" -> 3
                                |>
                            ]
                        ] && logged === {processed} && sent === {
                            {
                                First[
                                    packet["SourceSocket"]
                                ],
                                "127.0.0.1:9000",
                                packet["DataByteArray"]
                            }
                        }
                    ]
                ],
                True,
                TestID -> "udp-final-packet-preserves-request-address-and-response"
            ],
            VerificationTest[
                Block[{
                    sent = 0,
                    logged = {},
                    WLJS`CSockets`Private`socketSend = Function[Null,
                        sent++;
                        0
                    ],
                    WLJS`CSockets`Private`socketSendTo = Function[Null,
                        sent++;
                        0
                    ]
                },
                    Module[{handler, packets, processed},
                        handler = CSocketHandler[
                            "Accepted" -> Function[p,
                                "accepted"
                            ],
                            "Closed" -> Function[p,
                                "closed"
                            ],
                            "Error" -> Function[p,
                                "error"
                            ],
                            "Logger" -> Function[p,
                                AppendTo[logged, p];
                                "ignored"
                            ]
                        ];
                        packets = <|
                            "Event" -> #
                        |>& /@ {"Accepted", "Closed", "Error"};
                        processed = handler /@ packets;
                        processed === MapThread[
                            Join[#1, <|"Handler" -> handler, "Result" -> #2|>]&,
                            {
                                packets,
                                {"accepted", "closed", "error"}
                            }
                        ] && logged === processed && sent === 0
                    ]
                ],
                True,
                TestID -> "non-data-events-return-and-log-packets-without-sending"
            ],
            VerificationTest[
                Block[{
                    sent = {},
                    logged = {},
                    WLJS`CSockets`Private`socketSend = Function[{row, bytes},
                        AppendTo[sent, bytes];
                        Length[bytes]
                    ]
                },
                    Module[{handler, packet, processed},
                        packet = <|
                            "Event" -> "Received",
                            "SourceSocket" -> CSocketObject[42],
                            "DataByteArray" -> ByteArray[{97}],
                            "Data" -> "a",
                            "DataLength" -> 1,
                            "ExpectedLength" -> 1,
                            "StoredLength" -> 1,
                            "Completed" -> True
                        |>;
                        handler = CSocketHandler[
                            "Received" -> Function[p,
                                p["Data"] <> "b"
                            ],
                            "Deserializer" -> ByteArrayToString,
                            "Serializer" -> StringToByteArray,
                            "Logger" -> Function[p,
                                AppendTo[logged, {p, sent}]
                            ]
                        ];
                        processed = handler[packet];
                        KeySort[processed] === KeySort[
                            Join[
                                packet,
                                <|
                                    "Handler" -> handler,
                                    "DataBytes" -> {97},
                                    "BufferKey" -> 42,
                                    "Result" -> ByteArray[{97, 98}]
                                |>
                            ]
                        ] && logged === {
                            {
                                processed,
                                {
                                    ByteArray[{97, 98}]
                                }
                            }
                        } && !KeyExistsQ[packet, "Result"]
                    ]
                ],
                True,
                TestID -> "handler-returns-and-logs-complete-packet-after-sending"
            ],
            VerificationTest[
                Block[{
                    sent = 0,
                    WLJS`CSockets`Private`socketSend = Function[Null,
                        sent++;
                        0
                    ],
                    WLJS`CSockets`Private`socketSendTo = Function[Null,
                        sent++;
                        0
                    ]
                },
                    {
                        WLJS`CSockets`Private`sendResponse[<||>],
                        WLJS`CSockets`Private`sendResponse[<|"Result" -> Null|>],
                        sent
                    }
                ],
                {Null, Null, 0},
                TestID -> "packet-without-response-does-not-send"
            ],
            VerificationTest[
                Quiet[Map[
                    Catch[WLJS`CSockets`Private`sendResponse[#]]&,
                    {
                        <|"Result" -> 123|>,
                        <|"Result" -> "ok"|>,
                        <|"Result" -> "ok", "SourceSocket" -> CSocketObject[42], "Address" -> "invalid"|>
                    }
                ]],
                {
                    Failure["CSocketHandler", <|"Field" -> "Result", "Value" -> 123|>],
                    Failure["CSocketHandler", <|"Field" -> "SourceSocket", "Value" -> Missing["KeyAbsent", "SourceSocket"]|>],
                    Failure["CSocketHandler", <|"Field" -> "Address", "Value" -> "invalid"|>]
                },
                TestID -> "response-validates-packet-fields"
            ]
        }
    ]
]
