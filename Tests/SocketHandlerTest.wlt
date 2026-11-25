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
