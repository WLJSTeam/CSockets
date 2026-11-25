Needs["MUnit`"];


Get[
    FileNameJoin[
        {DirectoryName[$InputFileName, 2], "Kernel", "CSockets.wl"}
    ]
];


Begin["WLJS`CSockets`Private`"];


report = TestReport[
    Flatten[
        Table[
            VerificationTest[
                Module[{
                    server,
                    client,
                    task,
                    events = {},
                    received,
                    accepted,
                    result,
                    port
                },
                    server = createSocket[
                        First[endpoint],
                        protocol
                    ];
                    bind[
                        server,
                        Last[endpoint],
                        0
                    ];
                    If[protocol === "TCP",
                        listen[server]
                    ];
                    port = ToExpression[
                        Last[
                            StringSplit[
                                $CSockets[server, "LocalAddress"],
                                ":"
                            ]
                        ]
                    ];
                    task = SocketListen[
                        CSocketObject[server],
                        ( AppendTo[events, #] )&
                    ];
                    client = createSocket[
                        First[endpoint],
                        protocol
                    ];
                    connect[
                        client,
                        Last[endpoint],
                        port
                    ];
                    socketSend[
                        client,
                        ByteArray[{112, 105, 110, 103}]
                    ];
                    Do[
                        Pause[0.02];
                        If[AnyTrue[
                                events,
                                MemberQ[
                                    {"Received", "ReceivedFrom"},
                                    #["Event"]
                                ]&
                            ],
                            Break[]
                        ],
                        {150}
                    ];
                    received = SelectFirst[
                        events,
                        MemberQ[
                            {"Received", "ReceivedFrom"},
                            #["Event"]
                        ]&,
                        <||>
                    ];
                    result = Lookup[received, "DataBytes", {}] === {112, 105, 110, 103};
                    If[protocol === "TCP",
                        accepted = Lookup[
                            SelectFirst[
                                events,
                                #["Event"] === "Accepted"&,
                                <||>
                            ],
                            "AcceptedSocket",
                            CSocketObject[-1]
                        ];
                        result = result && Lookup[received, "SourceSocket", Null] === accepted;
                        close[client];
                        Do[
                            Pause[0.02];
                            If[AnyTrue[
                                    events,
                                    #["Event"] === "Closed"&
                                ],
                                Break[]
                            ],
                            {150}
                        ];
                        result = result && AnyTrue[
                            events,
                            #["Event"] === "Closed"&
                        ] && !KeyExistsQ[
                            $CSockets,
                            First[accepted]
                        ],
                        socketSend[
                            client,
                            ByteArray[{}]
                        ];
                        Do[
                            Pause[0.02];
                            If[Length[events] > 1,
                                Break[]
                            ],
                            {150}
                        ];
                        result = result && Last[events]["DataBytes"] === {};
                        close[client]
                    ];
                    RemoveAsynchronousTask[task];
                    Pause[1.1];
                    result = result && socketValidQ[server];
                    close[server];
                    result
                ],
                True,
                TestID -> ( "native-read-" <> First[endpoint] <> "-" <> protocol )
            ],
            {
                endpoint,
                {
                    {"IPv4", "127.0.0.1"},
                    {"IPv6", "::1"}
                }
            },
            {
                protocol,
                {"TCP", "UDP"}
            }
        ]
    ]
];


Print[
    "Async poll loop: ",
    report["TestsSucceededCount"],
    " passed; ",
    report["TestsFailedCount"],
    " failed"
];


If[report["TestsFailedCount"] > 0,
    Print[
        report["TestsFailed"]
    ]
];


End[];


WLJS`CSockets`Private`report
