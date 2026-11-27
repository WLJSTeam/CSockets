Needs["MUnit`"];


Get[
    FileNameJoin[
        {DirectoryName[$InputFileName, 2], "Kernel", "CSockets.wl"}
    ]
];


Begin["WLJS`CSockets`Private`"];


nativeSocketReport = TestReport[
    {
        VerificationTest[
            And @@ (
                MatchQ[#, _LibraryFunctionError]& /@ Quiet[
                    {
                        socketPollLoopCreate[{10}, {}, 1000, $POLLIN, 65536],
                        socketPollLoopCreate[{}, {}, -2, $POLLIN, 65536],
                        socketPollLoopCreate[{}, {}, -1, $POLLIN, 65536],
                        socketPollLoopCreate[{-1}, {$SOCKETROLETCPBOUND}, 1000, $POLLIN, 65536],
                        socketPollLoopCreate[{10}, {99}, 1000, $POLLIN, 65536],
                        socketPollLoopCreate[{}, {}, 1000, $POLLIN, 0],
                        socketPollLoopCreate[{}, {}, 1000, $POLLIN, 2 ^ 31]
                    }
                ]
            ),
            True,
            TestID -> "poll-loop-rejects-invalid-lengths-timeout-descriptors-roles-and-buffer-size"
        ],
        VerificationTest[
            Module[{
                server = CSocketOpen["127.0.0.1", 0],
                client, acceptedSocketId, accepted, count, invalid, result,
                payload = NumericArray[Range[0, 127], "UnsignedInteger8"],
                buffer = ByteArray[ConstantArray[255, 512]]
            },
                client = CSocketConnect[server["LocalAddress"]];
                acceptedSocketId = accept[First[server]];
                registerAcceptedSocket[First[server], acceptedSocketId];
                accepted = CSocketObject[acceptedSocketId];

                invalid = Quiet[{
                    socketSendRange[First[client], payload, -1, 1],
                    socketSendRange[First[client], payload, 0, -1],
                    socketSendRange[First[client], payload, 129, 0],
                    socketSendRange[First[client], payload, 127, 2],
                    socketSendRange[First[client], payload, 1, 2 ^ 62],
                    socketRecvInto[acceptedSocketId, ByteArray[{}]]
                }];

                result = AllTrue[invalid, MatchQ[#, _LibraryFunctionError]&] &&
                    !TrueQ[SocketReadyQ[accepted]] &&
                    socketSendRange[First[client], payload, 32, 96] === 96;

                count = 0;
                While[result && count < 96 && TrueQ[SocketReadyQ[accepted, 1]],
                    With[{received = socketRecvInto[acceptedSocketId, buffer]},
                        If[!IntegerQ[received] || received <= 0,
                            result = False,
                            result = Take[Normal[buffer], received] === Range[32 + count, 31 + count + received] &&
                                Last[Normal[buffer]] === 255;
                            count += received
                        ]
                    ]
                ];

                Close[client];
                result = result && count === 96 &&
                    AnyTrue[poll[{acceptedSocketId}, 1], BitAnd[Last[#], BitOr[$POLLIN, $POLLHUP]] != 0&] &&
                    socketRecvInto[acceptedSocketId, buffer] === 0;
                Scan[Close, {accepted, server}];
                result
            ],
            True,
            TestID -> "tcp-receive-into-and-send-range-preserve-offset-buffer-and-eof"
        ],
        VerificationTest[
            Module[{
                server = CSocketOpen["127.0.0.1", 0, "UDP"],
                sender = CSocketOpen["127.0.0.1", 0, "UDP"],
                buffer = NumericArray[ConstantArray[255, 16], "UnsignedInteger8"],
                payload = ByteArray[{0, 7, 11, 19, 255}],
                destination, senderAddress, result
            },
                destination = splitAddress[server["LocalAddress"]];
                senderAddress = StringDelete[sender["LocalAddress"], StartOfString ~~ "udp://"];

                result = socketSendToRange[
                    First[sender], destination["Host"], ToString[destination["Port"]], payload, 1, 3
                ] === 3 && TrueQ[SocketReadyQ[server, 1]] &&
                    List @@ socketRecvFromInto[First[server], buffer] === {3, senderAddress} &&
                    Normal[buffer] === Join[{7, 11, 19}, ConstantArray[255, 13]];

                result = result && socketSendToRange[
                    First[sender], destination["Host"], ToString[destination["Port"]], payload, 5, 0
                ] === 0 && TrueQ[SocketReadyQ[server, 1]] &&
                    List @@ socketRecvFromInto[First[server], buffer] === {0, senderAddress};

                Scan[Close, {sender, server}];
                result
            ],
            True,
            TestID -> "udp-range-and-receive-into-return-length-and-address"
        ],
        VerificationTest[
            Module[{
                task,
                events = {}
            },
                task = Internal`CreateAsynchronousTask[
                    socketPollLoopCreate,
                    {
                        {},
                        {},
                        10000,
                        $POLLIN,
                        65536
                    },
                    (
                        AppendTo[events, {#2, #3}]
                    )&
                ];
                Pause[0.1];
                (* An empty loop may already have been removed by the kernel. *)
                Quiet[
                    RemoveAsynchronousTask[task],
                    RemoveAsynchronousTask::asyncobj
                ];
                events === {}
            ],
            True,
            TestID -> "empty-private-list-exits-without-polling"
        ],
        VerificationTest[
            Module[{
                receivers,
                sender,
                task,
                events = {},
                record,
                ports,
                result
            },
                receivers = Table[
                    createSocket["IPv4", "UDP"],
                    {2}
                ];
                Scan[
                    bind[#, "127.0.0.1", 0]&,
                    receivers
                ];
                ports = splitAddress[
                    $CSockets[#, "LocalAddress"]
                ]["Port"]& /@ receivers;
                record = Function[socketId,
                    Function[event,
                        AppendTo[events, {socketId, event["SourceSocket"], event["DataBytes"], event["Event"]}]
                    ]
                ];
                task = With[{first = receivers[[1]], second = receivers[[2]]},
                    SocketListen[{
                        CSocketObject[first] -> record[first],
                        {CSocketObject[second], record[second]}
                    }]
                ];
                sender = createSocket["IPv4", "UDP"];
                Scan[
                    socketSendTo[
                        sender,
                        "127.0.0.1",
                        ToString[#],
                        ByteArray[{7}]
                    ]&,
                    ports
                ];
                Do[
                    Pause[0.02];
                    If[Length[events] >= 2,
                        Break[]
                    ],
                    {150}
                ];
                result = Sort[events] === Sort[Map[{#, CSocketObject[#], {7}, "ReceivedFrom"}&, receivers]] &&
                    AllTrue[receivers, Function[socketId,
                        $CSockets[socketId, "Listener"] === task &&
                            MemberQ[Normal[$CSockets[socketId]], HoldPattern["Handler" -> _Function]]
                    ]];
                RemoveAsynchronousTask[task];
                Pause[1.1];
                result = result && AllTrue[receivers, socketValidQ];
                Scan[
                    close,
                    Append[receivers, sender]
                ];
                result
            ],
            True,
            TestID -> "multiple-initial-sockets-share-task-and-survive-cancellation"
        ],
        VerificationTest[
            Module[{
                socketId,
                task,
                events = {},
                result
            },
                socketId = createSocket["IPv4", "UDP"];
                bind[socketId, "127.0.0.1", 0];
                Do[
                    task = Internal`CreateAsynchronousTask[
                        socketPollLoopCreate,
                        {
                            {socketId, socketId},
                            {$SOCKETROLEUDPBOUND, $SOCKETROLEUDPBOUND},
                            1000,
                            $POLLIN,
                            65536
                        },
                        (
                            AppendTo[events, {#2, #3}]
                        )&
                    ];
                    RemoveAsynchronousTask[task],
                    {25}
                ];
                Pause[0.1];
                result = events === {} && socketValidQ[socketId];
                close[socketId];
                result
            ],
            True,
            TestID -> "repeated-task-cancellation-releases-private-lists-and-preserves-sockets"
        ],
        VerificationTest[
            Module[{receiver, sender, port, task, ready, result},
                receiver = createSocket["IPv4", "UDP"];
                bind[receiver, "127.0.0.1", 0];
                toNonBlocking[receiver];
                port = splitAddress[
                    $CSockets[receiver, "LocalAddress"]
                ]["Port"];
                sender = createSocket["IPv4", "UDP"];
                task = Internal`CreateAsynchronousTask[
                    socketPollLoopCreate,
                    {
                        {receiver},
                        {$SOCKETROLEUDPBOUND},
                        500000,
                        $POLLIN,
                        65536
                    },
                    Function[Null
                    ]
                ];
                Pause[0.05];
                RemoveAsynchronousTask[task];
                socketSendTo[
                    sender,
                    "127.0.0.1",
                    ToString[port],
                    ByteArray[{42}]
                ];
                Pause[0.6];
                ready = socketsPoll[{receiver}, 0, $POLLIN];
                result = ready === {
                    {receiver, $POLLIN}
                };
                If[result,
                    result = Normal[
                        Last[
                            socketRecvFrom[
                                receiver,
                                ByteArray[{0}]
                            ]
                        ]
                    ] === {42}
                ];
                Scan[close, {receiver, sender}];
                result
            ],
            True,
            TestID -> "cancelled-poll-loop-leaves-new-datagram-unread-after-waking"
        ],
        VerificationTest[
            Module[{
                server,
                clients,
                task,
                events = {},
                accepted,
                port,
                result
            },
                server = createSocket["IPv4", "TCP"];
                bind[server, "127.0.0.1", 0];
                listen[server];
                port = splitAddress[
                    $CSockets[server, "LocalAddress"]
                ]["Port"];
                task = SocketListen[
                    CSocketObject[server],
                    ( AppendTo[events, #] )&
                ];
                clients = Table[
                    With[{socketId = createSocket["IPv4", "TCP"]},
                        connect[socketId, "127.0.0.1", port];
                        socketId
                    ],
                    {12}
                ];
                Do[
                    Pause[0.02];
                    If[Count[
                            Lookup[events, "Event"],
                            "Accepted"
                        ] === 12,
                        Break[]
                    ],
                    {150}
                ];
                accepted = Lookup[
                    Select[
                        events,
                        #["Event"] === "Accepted"&
                    ],
                    "AcceptedSocket"
                ];
                result = Length[accepted] === 12;
                Scan[
                    socketSend[
                        #,
                        ByteArray[{8}]
                    ]&,
                    clients
                ];
                Do[
                    Pause[0.02];
                    If[Count[
                            Lookup[events, "Event"],
                            "Received"
                        ] === 12,
                        Break[]
                    ],
                    {150}
                ];
                result = result && Count[
                    Lookup[events, "Event"],
                    "Received"
                ] === 12;
                Scan[close, clients];
                Do[
                    Pause[0.02];
                    If[Count[
                            Lookup[events, "Event"],
                            "Closed"
                        ] === 12,
                        Break[]
                    ],
                    {150}
                ];
                result = result && Count[
                    Lookup[events, "Event"],
                    "Closed"
                ] === 12 && NoneTrue[
                    First /@ accepted,
                    KeyExistsQ[$CSockets, #]&
                ];
                RemoveAsynchronousTask[task];
                Pause[1.1];
                close[server];
                result
            ],
            True,
            TestID -> "private-list-grows-and-prunes-twelve-accepted-connections"
        ]
    }
];


Print[
    "Native socket: ",
    nativeSocketReport["TestsSucceededCount"],
    " passed; ",
    nativeSocketReport["TestsFailedCount"],
    " failed"
];


If[nativeSocketReport["TestsFailedCount"] > 0,
    Print[
        nativeSocketReport["TestsFailed"]
    ]
];


End[];


WLJS`CSockets`Private`nativeSocketReport
