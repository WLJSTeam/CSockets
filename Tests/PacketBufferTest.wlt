Needs["MUnit`"];


baseDir = DirectoryName[$InputFileName, 2];


Get[
    FileNameJoin[{baseDir, "Kernel", "CSockets.wl"}]
];


TestReport[
    {
        VerificationTest[
            Block[{
                sent = {},
                logged = {},
                decoded = {},
                expectedCalls = 0,
                WLJS`CSockets`Private`socketSend = Function[{row, bytes},
                    AppendTo[sent, bytes];
                    Length[bytes]
                ]
            },
                Module[{handler, packet, first, last, before},
                    handler = CSocketHandler[
                        "Accumulator" -> Function[p,
                            expectedCalls++;
                            4
                        ],
                        "Deserializer" -> Function[bytes,
                            AppendTo[decoded, bytes];
                            ByteArrayToString[bytes]
                        ],
                        "Received" -> Function[p,
                            ToUpperCase[
                                p["Data"]
                            ]
                        ],
                        "Logger" -> Function[p,
                            AppendTo[logged, p]
                        ]
                    ];
                    packet = <|
                        "Event" -> "Received",
                        "SourceSocket" -> CSocketObject[42]
                    |>;
                    first = handler[
                        Append[
                            packet,
                            "DataByteArray" -> StringToByteArray["ab"]
                        ]
                    ];
                    before = sent === {} && decoded === {} && !first["Completed"] && first["StoredLength"] === 2 && !KeyExistsQ[first, "Result"];
                    last = handler[
                        Append[
                            packet,
                            "DataByteArray" -> StringToByteArray["cd"]
                        ]
                    ];
                    before && last["Completed"] && last["Handler"] === handler && last["Data"] === "abcd" && last["DataByteArray"] === StringToByteArray["abcd"] && last["DataBytes"] === ToCharacterCode["abcd"] && last["DataLength"] === 2 && last["StoredLength"] === 4 && last["ExpectedLength"] === 4 && last["Result"] === "ABCD" && sent === {StringToByteArray["ABCD"]} && decoded === {StringToByteArray["abcd"]} && expectedCalls === 1 && logged === {first, last}
                ]
            ],
            True,
            TestID -> "fragments-complete-before-deserialization-handler-and-send"
        ],
        VerificationTest[
            Module[{
                handler,
                packet,
                messages = {},
                result
            },
                handler = CSocketHandler[
                    "Accumulator" -> <|
                        "three" :> Function[p,
                            True
                        ] :> Function[p,
                            3
                        ]
                    |>,
                    "Deserializer" -> ByteArrayToString,
                    "Received" -> <|
                        "collect" :> Function[p,
                            True
                        ] :> Function[p,
                            AppendTo[
                                messages,
                                p["Data"]
                            ];
                            Null
                        ]
                    |>
                ];
                packet = <|
                    "Event" -> "Received",
                    "SourceSocket" -> CSocketObject[42]
                |>;
                result = handler[
                    Append[
                        packet,
                        "DataByteArray" -> StringToByteArray["abcdefg"]
                    ]
                ];
                messages === {"abc", "def"} && !result["Completed"] && result["StoredLength"] === 1 && With[{
                    last = handler[
                        Append[
                            packet,
                            "DataByteArray" -> StringToByteArray["hi"]
                        ]
                    ]
                },
                    messages === {"abc", "def", "ghi"} && last["Completed"] && last["Data"] === "ghi"
                ]
            ],
            True,
            TestID -> "coalesced-messages-and-trailing-fragment-are-preserved"
        ],
        VerificationTest[
            Module[{
                handler,
                packet,
                received = {},
                first,
                second
            },
                handler = CSocketHandler[
                    "Accumulator" -> Function[p,
                        2
                    ],
                    "Deserializer" -> ByteArrayToString,
                    "ReceivedFrom" -> Function[p,
                        AppendTo[
                            received,
                            {p["Address"], p["Data"]}
                        ];
                        Null
                    ]
                ];
                packet = <|
                    "Event" -> "ReceivedFrom",
                    "SourceSocket" -> CSocketObject[42]
                |>;
                first = Append[packet, "Address" -> "127.0.0.1:1"];
                second = Append[packet, "Address" -> "127.0.0.1:2"];
                handler[
                    Append[
                        first,
                        "DataByteArray" -> StringToByteArray["a"]
                    ]
                ];
                handler[
                    Append[
                        second,
                        "DataByteArray" -> StringToByteArray["x"]
                    ]
                ];
                handler[
                    Append[
                        first,
                        "DataByteArray" -> StringToByteArray["b"]
                    ]
                ];
                handler[
                    Append[
                        second,
                        "DataByteArray" -> StringToByteArray["y"]
                    ]
                ];
                received === {
                    {first["Address"], "ab"},
                    {second["Address"], "xy"}
                }
            ],
            True,
            TestID -> "udp-fragment-buffers-are-separated-by-sender"
        ]
    }
]
