Needs["MUnit`"];


baseDir = If[$InputFileName === "",
    Directory[],
    DirectoryName[$InputFileName, 2]
];


Get[
    FileNameJoin[{baseDir, "Kernel", "CSockets.wl"}]
];


socketHandlerTests = {
    VerificationTest[
        Module[{
            first = CSocketHandler["Received" -> Function["first"]],
            second = CSocketHandler["Received" -> Function["second"]]
        },
            first["Logger"] = Function["first logger"];
            first["Buffer"]["Insert", "fragment" -> ByteArray[{1}]];

            first["Received"][<||>] === "first" && second["Received"][<||>] === "second" &&
                first["Logger"][42] === "first logger" && second["Logger"][42] === 42 &&
                MissingQ[second["Buffer"]["Lookup", "fragment"]]
        ],
        True,
        TestID -> "handler-instances-have-independent-callbacks-options-and-buffers"
    ],
    VerificationTest[
        Lookup[
            WLJS`CSockets`Private`createEventData["Accepted", 10, 20],
            "AcceptedSocket"
        ] === WLJS`CSockets`CSocketObject[20],
        True,
        TestID -> "accepted-event-structure"
    ],
    VerificationTest[
        Lookup[
            WLJS`CSockets`Private`createEventData["Closed", 1, Null],
            "ClosedSocket"
        ] === WLJS`CSockets`CSocketObject[1],
        True,
        TestID -> "closed-event-structure"
    ],
    VerificationTest[
        Lookup[
            WLJS`CSockets`Private`createEventData["Error", 4, 99],
            "ErrorCode"
        ] === 99,
        True,
        TestID -> "error-event-carries-code"
    ],
    VerificationTest[
        With[{
            event = WLJS`CSockets`Private`createEventData["ReceivedFrom", 7, "127.0.0.1:123"]
        },
            And[
                Lookup[event, "SourceSocket"] === WLJS`CSockets`CSocketObject[7],
                Lookup[event, "Address"] === "127.0.0.1:123"
            ]
        ],
        True,
        TestID -> "receivedfrom-address-only-conversion"
    ],
    VerificationTest[
        With[{
            event = WLJS`CSockets`Private`createEventData["ReceivedFrom", 7, "127.0.0.1:123", {65, 66, 67}]
        },
            And[
                Lookup[event, "SourceSocket"] === WLJS`CSockets`CSocketObject[7],
                Lookup[event, "Address"] === "127.0.0.1:123",
                Lookup[event, "Data"] === "ABC",
                Lookup[event, "DataBytes"] === {65, 66, 67},
                Lookup[event, "DataByteArray"] === ByteArray[{65, 66, 67}]
            ]
        ],
        True,
        TestID -> "receivedfrom-address-and-data-conversion"
    ],
    VerificationTest[
        With[{
            event = WLJS`CSockets`Private`createEventData["Received", 7, {65, 66, 67}]
        },
            And[
                Lookup[event, "SourceSocket"] === WLJS`CSockets`CSocketObject[7],
                Lookup[event, "Data"] === "ABC",
                Lookup[event, "DataBytes"] === {65, 66, 67},
                Lookup[event, "DataByteArray"] === ByteArray[{65, 66, 67}]
            ]
        ],
        True,
        TestID -> "received-event-conversion"
    ],
    VerificationTest[
        Module[{handler = WLJS`CSockets`CSocketHandler[]},
            And[
                handler["Logger"][42] === 42,
                handler["Accumulator"][
                    <|
                        "DataByteArray" -> ByteArray[{1, 2, 3, 4}]
                    |>
                ] === 4,
                handler["Serializer"][5] === 5,
                handler["Deserializer"][
                    ByteArray[{65}]
                ] === ByteArray[{65}],
                handler["Received"][<||>] === Null,
                handler["Accepted"][<||>] === Null,
                handler["Closed"][<||>] === Null,
                handler["Error"][<||>] === Null
            ]
        ],
        True,
        TestID -> "handler-default-options"
    ],
    VerificationTest[
        Module[{handler = WLJS`CSockets`CSocketHandler[]},
            And[
                MemberQ[
                    Keys[
                        Options[WLJS`CSockets`CSocketHandler]
                    ],
                    "Received"
                ],
                MemberQ[
                    Keys[
                        Options[WLJS`CSockets`CSocketHandler]
                    ],
                    "Error"
                ]
            ]
        ],
        True,
        TestID -> "handler-exposes-expected-options"
    ],
    VerificationTest[
        Module[{handler = WLJS`CSockets`CSocketHandler[]},
            handler["Logger"] = "custom";
            handler["Logger"] === "custom"
        ],
        True,
        TestID -> "handler-setter-updates-single-key"
    ],
    VerificationTest[
        With[{
            handler = WLJS`CSockets`CSocketHandler[],
            logger = Function[value,
                {"logged", value}
            ]
        },
            handler["Logger"] = logger;
            handler["Logger"] === logger
        ],
        True,
        TestID -> "handler-setter-stores-logger-function"
    ],
    VerificationTest[
        Module[{handler = WLJS`CSockets`CSocketHandler[]},
            StringContainsQ[
                ToString[
                    InputForm[handler]
                ],
                "CSocketHandler"
            ]
        ],
        True,
        TestID -> "handler-format-is-readable"
    ],
    VerificationTest[
        Block[{
            sent = {},
            WLJS`CSockets`Private`socketSend = Function[{id, bytes},
                AppendTo[
                    sent,
                    {id, Normal[bytes]}
                ];
                Length[bytes]
            ]
        },
            With[{client = CSocketObject[33]},
                {
                    WLJS`CSockets`Private`sendResponse[<|"SourceSocket" -> client, "Result" -> "ok"|>],
                    WLJS`CSockets`Private`sendResponse[
                        <|
                            "SourceSocket" -> client,
                            "Result" -> ByteArray[{1, 2}]
                        |>
                    ],
                    WLJS`CSockets`Private`sendResponse[<|"SourceSocket" -> client, "Result" -> Null|>],
                    sent
                }
            ]
        ],
        {
            2,
            2,
            Null,
            {
                {
                    33,
                    {111, 107}
                },
                {
                    33,
                    {1, 2}
                }
            }
        },
        TestID -> "handler-response-sends-supported-types"
    ],
    VerificationTest[
        Module[{server, listener, clients, handler, logged = {}, fragmented, replies = {}, custom, result},
            handler = CSocketHandler[
                "Accumulator" -> Function[4],
                "Received" -> (#DataByteArray&),
                "Serializer" -> Function[bytes, Join[bytes, ByteArray[{254}]]],
                "Logger" -> (AppendTo[logged, #]&)
            ];
            server = SocketOpen[0];
            listener = SocketListen[server, handler];
            clients = Table[SocketConnect[server["DestinationPort"]], {2}];
            BinaryWrite[clients[[1]], ByteArray[{0, 128}]];
            BinaryWrite[clients[[2]], ByteArray[{2, 3}]];
            Do[Pause[0.02]; If[Length[logged] >= 2, Break[]], {100}];
            fragmented = Lookup[logged, "Completed"] === {False, False} &&
                Length[DeleteDuplicates[Lookup[logged, "BufferKey"]]] === 2;

            BinaryWrite[clients[[1]], ByteArray[{255, 1}]];
            BinaryWrite[clients[[2]], ByteArray[{4, 5}]];
            Do[Pause[0.02]; If[Length[logged] >= 4, Break[]], {100}];
            If[Length[logged] === 4, replies = ReadByteArray[#, 5]& /@ clients];

            handler["NativeReceived"] = Function[ByteArray[{42}]];
            BinaryWrite[clients[[1]], ByteArray[{6, 7, 8, 9}]];
            Do[Pause[0.02]; If[Length[logged] >= 5, Break[]], {100}];
            custom = If[Length[logged] === 5, ReadByteArray[First[clients], 2], Missing["NoReply"]];

            result = fragmented && replies === {ByteArray[{0, 128, 255, 1, 254}], ByteArray[{2, 3, 4, 5, 254}]} &&
                custom === ByteArray[{42, 254}] && handler["Buffer"]["Length"] === 0 &&
                AllTrue[logged, #["Event"] === "Received" && MatchQ[#["Timestamp"], _DateObject] &&
                    #["Socket"] === server && MatchQ[#["SourceSocket"], _SocketObject]&];
            Scan[Close, clients];
            DeleteObject[listener];
            Close[server];
            result
        ],
        True,
        TestID -> "handler-supports-native-tcp-listener-with-binary-fragments-and-custom-callback"
    ],
    VerificationTest[
        Block[{
            message = WLJS`CSockets`Private`conditionApply[
                <|
                    "plus" :> Function[x,
                        True
                    ] :> Function[x,
                        x + 1
                    ],
                    "minus" :> Function[x,
                        False
                    ] :> Function[x,
                        x - 1
                    ]
                |>
            ]
        },
            And[
                message[10] === 11,
                WLJS`CSockets`Private`conditionApply[
                    <||>,
                    Function[Null
                    ]
                ][123] === Null
            ]
        ],
        True,
        TestID -> "condition-apply-picks-first-matching-branch"
    ]
};


TestReport[
    socketHandlerTests
]
