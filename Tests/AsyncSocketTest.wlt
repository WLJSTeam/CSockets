Needs["MUnit`"];


baseDir = DirectoryName[$InputFileName, 2];


Get[
    FileNameJoin[{baseDir, "Kernel", "CSockets.wl"}]
];


TestReport[
    Flatten[
        Table[
            VerificationTest[
                Module[{
                    server,
                    client,
                    task,
                    events = {},
                    received,
                    result
                },
                    server = CSocketOpen[host, 0, protocol];
                    task = SocketListen[
                        {server -> (AppendTo[events, #]&)}
                    ];
                    client = CSocketConnect[
                        host,
                        WLJS`CSockets`Private`splitAddress[
                            server["LocalAddress"]
                        ]["Port"],
                        protocol,
                        "Wait" -> True
                    ];
                    WriteString[client, "ping"];
                    Do[
                        Pause[0.05];
                        If[AnyTrue[
                                events,
                                MemberQ[
                                    {"Received", "ReceivedFrom"},
                                    #["Event"]
                                ]&
                            ],
                            Break[]
                        ],
                        {60}
                    ];
                    received = SelectFirst[
                        events,
                        MemberQ[
                            {"Received", "ReceivedFrom"},
                            #["Event"]
                        ]&,
                        <||>
                    ];
                    result = KeyExistsQ[received, "SourceSocket"] && IntegerQ[
                        First[
                            received["SourceSocket"]
                        ]
                    ] && received["DataBytes"] === {112, 105, 110, 103};
                    If[protocol === "UDP",
                        result = result && received["Address"] === If[host === "::1",
                            "[::1]",
                            host
                        ] <> ":" <> ToString[
                            WLJS`CSockets`Private`splitAddress[
                                client["LocalAddress"]
                            ]["Port"]
                        ]
                    ];
                    If[protocol === "TCP",
                        result = result && AnyTrue[
                            events,
                            #["Event"] === "Accepted" && MatchQ[
                                #["AcceptedSocket"],
                                CSocketObject[_Integer]
                            ]&
                        ]
                    ];
                    RemoveAsynchronousTask[task];
                    Pause[1.1];
                    If[protocol === "TCP" && KeyExistsQ[received, "SourceSocket"],
                        Close[
                            received["SourceSocket"]
                        ]
                    ];
                    Scan[Close, {client, server}];
                    result
                ],
                True,
                TestID -> ( "async-string-address-" <> host <> "-" <> protocol )
            ],
            {
                host,
                {"127.0.0.1", "::1"}
            },
            {
                protocol,
                {"TCP", "UDP"}
            }
        ]
    ]
]
