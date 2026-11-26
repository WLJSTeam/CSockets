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
            Block[{
                $CSockets = <|
                    10 -> <|
                        "Listener" -> AsynchronousTaskObject["first", 7, 100],
                        "Handler" -> "kept"
                    |>,
                    11 -> <|
                        "Listener" -> AsynchronousTaskObject["second", 7, 100]
                    |>,
                    12 -> <|
                        "Listener" -> AsynchronousTaskObject["other", 8, 100]
                    |>,
                    13 -> <|
                        "Listener" -> Null
                    |>,
                    14 -> <|
                        "Handler" -> "no listener"
                    |>
                |>
            },
                removeSocketListener[7];
                {
                    $CSockets[10, "Listener"],
                    $CSockets[11, "Listener"],
                    $CSockets[12, "Listener"],
                    $CSockets[13, "Listener"],
                    $CSockets[14],
                    $CSockets[10, "Handler"]
                }
            ],
            {
                Null,
                Null,
                AsynchronousTaskObject["other", 8, 100],
                Null,
                <|
                    "Handler" -> "no listener"
                |>,
                "kept"
            },
            TestID -> "cleanup-matches-task-id-and-preserves-unrelated-metadata"
        ],
        VerificationTest[
            And @@ Table[
                Module[{
                    servers,
                    task,
                    nextTask,
                    events = {},
                    cleared,
                    result,
                    sender,
                    port
                },
                    servers = Table[
                        CSocketOpen["127.0.0.1", 0, "UDP"],
                        {2}
                    ];
                    task = SocketListen[
                        Map[# -> Function[Null]&, servers]
                    ];
                    Switch[operation,
                        "Stop",
                        StopAsynchronousTask[task],
                        "Remove",
                        RemoveAsynchronousTask[task]
                    ];
                    cleared = AllTrue[
                        servers,
                        #["Listener"] === Null&
                    ];
                    If[operation === "Stop",
                        RemoveAsynchronousTask[task]
                    ];
                    Pause[1.1];
                    nextTask = SocketListen[
                        First[servers],
                        ( AppendTo[events, #] )&
                    ];
                    sender = CSocketOpen["127.0.0.1", 0, "UDP"];
                    port = ToExpression[
                        Last[
                            StringSplit[
                                First[servers]["LocalAddress"],
                                ":"
                            ]
                        ]
                    ];
                    socketSendTo[
                        First[sender],
                        "127.0.0.1",
                        ToString[port],
                        ByteArray[{42}]
                    ];
                    Do[
                        Pause[0.02];
                        If[Length[events] > 0,
                            Break[]
                        ],
                        {100}
                    ];
                    result = cleared && MatchQ[nextTask, _AsynchronousTaskObject] && nextTask =!= task && First[servers]["Listener"] === nextTask && Length[events] === 1 && First[events]["DataBytes"] === {42};
                    RemoveAsynchronousTask[nextTask];
                    Pause[1.1];
                    result = result && AllTrue[
                        servers,
                        #["Listener"] === Null&
                    ];
                    Scan[
                        Close,
                        Append[servers, sender]
                    ];
                    result
                ],
                {
                    operation,
                    {"Stop", "Remove"}
                }
            ],
            True,
            TestID -> "stop-and-remove-clear-all-task-sockets-and-allow-listening-again"
        ],
        VerificationTest[
            Module[{
                server,
                client,
                task,
                events = {},
                accepted,
                port,
                result
            },
                server = CSocketOpen["127.0.0.1", 0, "TCP"];
                task = SocketListen[
                    server,
                    ( AppendTo[events, #] )&
                ];
                port = ToExpression[
                    Last[
                        StringSplit[
                            server["LocalAddress"],
                            ":"
                        ]
                    ]
                ];
                client = CSocketConnect["127.0.0.1", port, "TCP"];
                Do[
                    Pause[0.02];
                    If[AnyTrue[
                            events,
                            #["Event"] === "Accepted"&
                        ],
                        Break[]
                    ],
                    {100}
                ];
                accepted = Lookup[
                    SelectFirst[
                        events,
                        #["Event"] === "Accepted"&,
                        <||>
                    ],
                    "AcceptedSocket",
                    CSocketObject[-1]
                ];
                RemoveAsynchronousTask[task];
                Pause[1.1];
                result = server["Listener"] === Null && accepted["Listener"] === Null && socketValidQ[
                    First[server]
                ] && socketValidQ[
                    First[accepted]
                ];
                Scan[Close, {accepted, client, server}];
                result
            ],
            True,
            TestID -> "accepted-sockets-are-detached-with-the-listening-socket"
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
