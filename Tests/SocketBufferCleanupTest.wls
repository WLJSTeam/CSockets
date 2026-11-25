Needs["MUnit`"];


Get[
    FileNameJoin[
        {DirectoryName[$InputFileName, 2], "Kernel", "CSockets.wl"}
    ]
];


Begin["WLJS`CSockets`Private`"];


report = TestReport[
    {
        VerificationTest[
            Block[{$CSockets = <||>, socketClose = Function[Null, Null]},
                Module[{handler = CSocketHandler["Accumulator" -> Function[2]], before},
                    registerSocket[42];
                    $CSockets[42, "Handler"] = handler;
                    dispatchPollEvent[
                        AsynchronousTaskObject[1],
                        "Received",
                        {
                            42,
                            ByteArray[{1}]
                        }
                    ];
                    before = !MissingQ[
                        handler["Buffer"]["Lookup", 42]
                    ];
                    Close[
                        CSocketObject[42]
                    ];
                    before && MissingQ[
                        handler["Buffer"]["Lookup", 42]
                    ] && !KeyExistsQ[$CSockets, 42]
                ]
            ],
            True,
            TestID -> "explicit-close-removes-incomplete-message"
        ],
        VerificationTest[
            Block[{$CSockets = <||>},
                Module[{
                    handler,
                    messages = {},
                    cleaned = False,
                    before,
                    packet
                },
                    handler = CSocketHandler[
                        "Accumulator" -> Function[2
                        ],
                        "Received" -> Function[p,
                            AppendTo[
                                messages,
                                p["DataBytes"]
                            ];
                            Null
                        ],
                        "Closed" -> Function[p,
                            cleaned = MissingQ[
                                p["Handler"]["Buffer"]["Lookup", 42]
                            ]
                        ]
                    ];
                    registerSocket[42];
                    $CSockets[42, "Handler"] = handler;
                    dispatchPollEvent[
                        AsynchronousTaskObject[1],
                        "Received",
                        {
                            42,
                            ByteArray[{1}]
                        }
                    ];
                    before = !MissingQ[
                        handler["Buffer"]["Lookup", 42]
                    ];
                    dispatchPollEvent[
                        AsynchronousTaskObject[1],
                        "Closed",
                        {42}
                    ];
                    registerSocket[42];
                    $CSockets[42, "Handler"] = handler;
                    packet = dispatchPollEvent[
                        AsynchronousTaskObject[1],
                        "Received",
                        {
                            42,
                            ByteArray[{2}]
                        }
                    ];
                    before = before && cleaned && !packet["Completed"] && messages === {};
                    dispatchPollEvent[
                        AsynchronousTaskObject[1],
                        "Received",
                        {
                            42,
                            ByteArray[{3}]
                        }
                    ];
                    before && messages === {
                        {2, 3}
                    } && MissingQ[
                        handler["Buffer"]["Lookup", 42]
                    ]
                ]
            ],
            True,
            TestID -> "peer-close-cleans-before-callback-and-descriptor-reuse-starts-fresh"
        ],
        VerificationTest[
            Block[{$CSockets = <||>, socketValidQ},
                Module[{handler = CSocketHandler["Accumulator" -> Function[2]], preserved},
                    registerSocket[42];
                    $CSockets[42, "Handler"] = handler;
                    dispatchPollEvent[
                        AsynchronousTaskObject[1],
                        "Received",
                        {
                            42,
                            ByteArray[{1}]
                        }
                    ];
                    socketValidQ[_Integer] :=
                    True;
                    dispatchPollEvent[
                        AsynchronousTaskObject[1],
                        "Error",
                        {42, 99}
                    ];
                    preserved = !MissingQ[
                        handler["Buffer"]["Lookup", 42]
                    ] && KeyExistsQ[$CSockets, 42];
                    socketValidQ[_Integer] :=
                    False;
                    dispatchPollEvent[
                        AsynchronousTaskObject[1],
                        "Error",
                        {42, 99}
                    ];
                    preserved && MissingQ[
                        handler["Buffer"]["Lookup", 42]
                    ] && !KeyExistsQ[$CSockets, 42]
                ]
            ],
            True,
            TestID -> "only-terminal-error-discards-incomplete-message"
        ],
        VerificationTest[
            Block[{$CSockets = <||>, socketClose = Function[Null, Null]},
                Module[{handler = CSocketHandler["Accumulator" -> Function[2]], before},
                    Scan[
                        registerSocket[#, "UDP", "Bound"]&,
                        {42, 43}
                    ];
                    Scan[
                        ( $CSockets[#, "Handler"] = handler )&,
                        {42, 43}
                    ];
                    dispatchPollEvent[
                        AsynchronousTaskObject[1],
                        "ReceivedFrom",
                        {
                            42,
                            "127.0.0.1:1",
                            ByteArray[{1}]
                        }
                    ];
                    dispatchPollEvent[
                        AsynchronousTaskObject[1],
                        "ReceivedFrom",
                        {
                            42,
                            "127.0.0.1:2",
                            ByteArray[{2}]
                        }
                    ];
                    dispatchPollEvent[
                        AsynchronousTaskObject[1],
                        "ReceivedFrom",
                        {
                            43,
                            "127.0.0.1:1",
                            ByteArray[{3}]
                        }
                    ];
                    before = Length[
                        handler["Buffer"]["Keys"]
                    ] === 3;
                    Close[
                        CSocketObject[42]
                    ];
                    before && handler["Buffer"]["Keys"] === {
                        {43, "127.0.0.1:1"}
                    }
                ]
            ],
            True,
            TestID -> "udp-close-removes-all-senders-and-preserves-other-socket"
        ]
    }
];


Print[
    "Passed: ",
    report["TestsSucceededCount"],
    "; failed: ",
    report["TestsFailedCount"]
];


If[report["TestsFailedCount"] > 0,
    Print[
        report["TestsFailed"]
    ];
    Exit[1]
];


End[];
