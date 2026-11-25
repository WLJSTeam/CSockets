Needs["MUnit`"];


Get[
    FileNameJoin[
        {DirectoryName[$InputFileName, 2], "Kernel", "CSockets.wl"}
    ]
];


Begin["WLJS`CSockets`Private`"];


coreReport = TestReport[
    {
        VerificationTest[
            Module[{
                server,
                client,
                task,
                events = {},
                accepted,
                closed,
                result
            },
                server = CSocketOpen["127.0.0.1", 0];
                task = SocketListen[
                    server,
                    ( AppendTo[events, #] )&
                ];
                client = CSocketConnect[
                    server["LocalAddress"]
                ];
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
                    $Failed
                ];
                result = MatchQ[
                    accepted,
                    CSocketObject[_Integer]
                ] && client["BlockingMode"] === "Blocking";
                Close[client];
                Do[
                    Pause[0.02];
                    If[AnyTrue[
                            events,
                            #["Event"] === "Closed"&
                        ],
                        Break[]
                    ],
                    {100}
                ];
                closed = Lookup[
                    SelectFirst[
                        events,
                        #["Event"] === "Closed"&,
                        <||>
                    ],
                    "ClosedSocket",
                    $Failed
                ];
                result = result && closed === accepted && !KeyExistsQ[
                    $CSockets,
                    First[accepted]
                ];
                RemoveAsynchronousTask[task];
                Pause[1.1];
                Close[server];
                result && !KeyExistsQ[
                    $CSockets,
                    First[server]
                ]
            ],
            True,
            TestID -> "async-peer-close-removes-accepted-registration"
        ],
        VerificationTest[
            Module[{
                server,
                client,
                task,
                events = {},
                result
            },
                server = CSocketOpen["127.0.0.1", 0, "UDP"];
                task = SocketListen[
                    server,
                    (
                        AppendTo[events, #];
                        Close[server]
                    )&
                ];
                client = CSocketConnect[
                    server["LocalAddress"]
                ];
                BinaryWrite[
                    client,
                    ByteArray[{}]
                ];
                Do[
                    Pause[0.02];
                    If[Length[events] > 0,
                        Break[]
                    ],
                    {100}
                ];
                result = Length[events] === 1 && First[events]["DataBytes"] === {} && !KeyExistsQ[
                    $CSockets,
                    First[server]
                ];
                Quiet[
                    RemoveAsynchronousTask[task],
                    RemoveAsynchronousTask::asyncobj
                ];
                Pause[1.1];
                Close[client];
                Close[server];
                result
            ],
            True,
            TestID -> "close-inside-empty-udp-callback-is-idempotent"
        ],
        VerificationTest[
            Module[{server, client, id, accepted, result},
                server = CSocketOpen["127.0.0.1", 0];
                client = CSocketConnect[
                    server["LocalAddress"]
                ];
                id = socketAccept[
                    First[server]
                ];
                registerAcceptedSocket[
                    First[server],
                    id
                ];
                accepted = CSocketObject[id];
                result = server["Role"] === "Bound" && client["Role"] === "Connected" && accepted["Role"] === "Accepted" && accepted["Addresses"] === Reverse[
                    client["Addresses"]
                ];
                BinaryWrite[
                    client,
                    ByteArray[{1, 2, 3, 4, 5}]
                ];
                result = result && socketRecv[
                    id,
                    ByteArray[{0, 0}]
                ] === ByteArray[{1, 2}] && SocketReadyQ[accepted, 1] && SocketWaitNext[{accepted}] === accepted && SocketWaitAll[{accepted}] === {accepted} && SocketReadMessage[accepted] === ByteArray[{3, 4, 5}];
                Scan[Close, {accepted, client, server}];
                result && Close[server] === Null
            ],
            True,
            TestID -> "synchronous-tcp-read-wait-and-close"
        ],
        VerificationTest[
            Module[{socket, task, result},
                socket = CSocketOpen["127.0.0.1", 0, "UDP"];
                task = SocketListen[
                    {socket},
                    Function[Null
                    ]
                ];
                RemoveAsynchronousTask[task];
                Pause[1.1];
                result = socketValidQ[
                    First[socket]
                ] && socket["Listener"] === Null;
                Close[socket];
                result && !KeyExistsQ[
                    $CSockets,
                    First[socket]
                ]
            ],
            True,
            TestID -> "cancel-listener-preserves-socket-and-clears-listener"
        ],
        VerificationTest[
            Quiet[
                CSocketConnect["localhost", 80, "TCP", "Wait" -> "invalid"]
            ],
            $Failed,
            TestID -> "invalid-wait-option-is-rejected"
        ]
    }
];


End[];


WLJS`CSockets`Private`coreReport
