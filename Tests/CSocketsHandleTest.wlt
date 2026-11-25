Needs["MUnit`"];


Get[FileNameJoin[{DirectoryName[$InputFileName, 2], "Kernel", "CSockets.wl"}]];


Begin["WLJS`CSockets`Private`"];


CSocketsHandleTest::native =
"Injected poll failure.";


handleReport = TestReport[{
    VerificationTest[
        Module[{server, clients, handler, events = {}, replies = {}, result, before = Keys[$CSockets]},
            server = CSocketOpen["127.0.0.1", 0];
            clients = Table[CSocketConnect[server["LocalAddress"]], {2}];
            Scan[WriteString[#, "ping"]&, clients];
            handler = CSocketHandler[
                "Deserializer" -> ByteArrayToString,
                "Received" -> (ToUpperCase[#Data]&),
                "Closed" -> Function[packet,
                    If[Count[Lookup[events, "Event"], "Closed"] === 1, Close[server]]
                ],
                "Logger" -> Function[packet,
                    AppendTo[events, packet];

                    If[packet["Event"] === "Received",
                        With[{client = SelectFirst[clients, #["LocalAddress"] === packet["SourceSocket"]["RemoteAddress"]&]},
                            AppendTo[replies, ReadString[client]];
                            Close[client]
                        ]
                    ]
                ]
            ];
            result = TimeConstrained[CSocketsHandle[{server}, handler], 8, "timeout"];
            result = result === Null && replies === {"PING", "PING"} &&
                Counts[Lookup[events, "Event"]] === <|"Accepted" -> 2, "Received" -> 2, "Closed" -> 2|> &&
                AllTrue[Select[events, #["Event"] === "Received"&], #["Socket"] === server&] &&
                AllTrue[Select[events, #["Event"] === "Closed"&], !KeyExistsQ[$CSockets, First[#["ClosedSocket"]]]&];
            Scan[Close, CSocketObject /@ Complement[Keys[$CSockets], before]];
            result
        ],
        True,
        TestID -> "synchronous-tcp-accept-reply-and-peer-close"
    ],
    VerificationTest[
        Module[{servers, clients, handler, packets = {}, result, before = Keys[$CSockets]},
            servers = CSocketOpen[#, 0, "UDP"]& /@ {"127.0.0.1", "::1"};
            clients = CSocketConnect[#["LocalAddress"]]& /@ servers;
            Scan[Function[client,
                BinaryWrite[client, ByteArray[{}]];
                WriteString[client, "ping"]
            ], clients];
            handler = CSocketHandler[
                "ReceivedFrom" -> (#DataByteArray&),
                "Logger" -> Function[packet,
                    AppendTo[packets, packet];

                    If[Length[packet["DataByteArray"]] > 0, Close[packet["SourceSocket"]]]
                ]
            ];
            result = TimeConstrained[CSocketsHandle[servers, handler], 8, "timeout"];
            result = result === Null && Length[packets] === 4 &&
                Sort[Lookup[packets, "DataBytes"]] === {{}, {}, {112, 105, 110, 103}, {112, 105, 110, 103}} &&
                AllTrue[packets, #["Event"] === "ReceivedFrom" && StringQ[#["Address"]]&] &&
                AllTrue[clients, SocketReadyQ[#, 1] && ReadByteArray[#] === ByteArray[{}] &&
                    SocketReadyQ[#, 1] && ReadString[#] === "ping"&];
            Scan[Close, CSocketObject /@ Complement[Keys[$CSockets], before]];
            result
        ],
        True,
        TestID -> "synchronous-multiple-udp-servers-ipv4-ipv6-empty-datagrams"
    ],
    VerificationTest[
        And @@ Table[
            Module[{server, client, accepted, managed, peer, handler, result, packets = {}, before = Keys[$CSockets]},
                server = CSocketOpen["127.0.0.1", 0];
                client = CSocketConnect[server["LocalAddress"]];
                accepted = socketAccept[First[server]];
                registerAcceptedSocket[First[server], accepted];
                {managed, peer} = If[role === "Connected", {client, CSocketObject[accepted]}, {CSocketObject[accepted], client}];
                WriteString[peer, "hello"];
                handler = CSocketHandler[
                    "Accumulator" -> Function[5],
                    "Received" -> (#DataByteArray&),
                    "Logger" -> Function[packet, AppendTo[packets, packet]; Close[managed]]
                ];
                result = TimeConstrained[CSocketsHandle[{managed}, handler], 8, "timeout"];
                result = result === Null && Length[packets] === 1 && First[packets]["Event"] === "Received" &&
                    First[packets]["SourceSocket"] === managed && SocketReadyQ[peer, 1] && ReadString[peer] === "hello";
                Scan[Close, CSocketObject /@ Complement[Keys[$CSockets], before]];
                result
            ],
            {role, {"Connected", "Accepted"}}
        ],
        True,
        TestID -> "synchronous-initial-connected-and-accepted-tcp-sockets"
    ],
    VerificationTest[
        Module[{server, client, handler, packet, result, before = Keys[$CSockets]},
            server = CSocketOpen["127.0.0.1", 0, "UDP"];
            client = CSocketConnect[server["LocalAddress"]];
            WriteString[server, client["LocalAddress"], "hello"];
            handler = CSocketHandler[
                "Received" -> (#DataByteArray&),
                "Logger" -> Function[received, packet = received; Close[client]]
            ];
            result = TimeConstrained[CSocketsHandle[{client}, handler], 8, "timeout"];
            result = result === Null && packet["Event"] === "Received" && !KeyExistsQ[packet, "Address"] &&
                SocketReadyQ[server, 1] && Last[SocketReadMessage[server]] === StringToByteArray["hello"];
            Scan[Close, CSocketObject /@ Complement[Keys[$CSockets], before]];
            result
        ],
        True,
        TestID -> "synchronous-connected-udp-replies-without-destination"
    ],
    VerificationTest[
        Module[{server, client, count = 0, result, before = Keys[$CSockets]},
            server = CSocketOpen["127.0.0.1", 0, "UDP"];
            client = CSocketConnect[server["LocalAddress"]];
            WriteString[client, "first"];
            WriteString[client, "second"];
            result = TimeConstrained[CSocketsHandle[{server, server}, Function[packet,
                count++;

                If[count === 1,
                    "reply",
                    Close[server]; Null
                ]
            ]], 8, "timeout"];
            result = result === Null && count === 2 && SocketReadyQ[client, 1] && ReadString[client] === "reply" &&
                !SocketReadyQ[client];
            Scan[Close, CSocketObject /@ Complement[Keys[$CSockets], before]];
            result
        ],
        True,
        TestID -> "synchronous-function-response-null-and-duplicate-input"
    ],
    VerificationTest[
        Module[{server, stale, client, handler, events = {}, nativePoll = socketsPoll, calls = 0, result, before = Keys[$CSockets]},
            server = CSocketOpen["127.0.0.1", 0, "UDP"];
            client = CSocketConnect[server["LocalAddress"]];
            stale = CSocketOpen["127.0.0.1", 0, "UDP"];
            socketClose[First[stale]];
            WriteString[client, "ping"];
            handler = CSocketHandler[
                "ReceivedFrom" -> (#DataByteArray&),
                "Logger" -> Function[packet,
                    AppendTo[events, packet];

                    If[packet["Event"] === "ReceivedFrom", Close[server]]
                ]
            ];
            handler["Buffer"]["Insert", {First[stale], "127.0.0.1:1"} -> CreateDataStructure["DynamicArray"]];
            result = Block[{socketsPoll = Function[{ids, timeout, mask},
                calls++;

                If[calls === 1,
                    Message[CSocketsHandleTest::native]; $Failed,
                    nativePoll[ids, timeout, mask]
                ]
            ]},
                TimeConstrained[CSocketsHandle[{stale, server}, handler], 8, "timeout"]
            ];
            result = result === Null && calls >= 2 && Lookup[events, "Event"] === {"Closed", "ReceivedFrom"} &&
                !KeyExistsQ[$CSockets, First[stale]] && handler["Buffer"]["Length"] === 0 &&
                SocketReadyQ[client, 1] && ReadString[client] === "ping";
            Scan[Close, CSocketObject /@ Complement[Keys[$CSockets], before]];
            result
        ],
        True,
        TestID -> "synchronous-poll-error-prunes-invalid-descriptors-and-continues"
    ],
    VerificationTest[
        Block[{socketsPoll = Function[Null, Message[CSocketsHandleTest::native]; $Failed]},
            Module[{server = CSocketOpen["127.0.0.1", 0, "UDP"], result},
                result = Quiet[TimeConstrained[CSocketsHandle[{server}, Function[Null]], 4, "timeout"]];
                Close[server];
                result === $Failed
            ]
        ],
        True,
        TestID -> "synchronous-unrecoverable-poll-error-terminates"
    ],
    VerificationTest[
        Module[{server, client, handler, messages = {}, buffered = False, cleaned = False, result, before = Keys[$CSockets]},
            server = CSocketOpen["::1", 0];
            client = CSocketConnect[server["LocalAddress"]];
            WriteString[client, "abcde"];
            handler = CSocketHandler[
                "Accumulator" -> Function[2],
                "Deserializer" -> ByteArrayToString,
                "Received" -> Function[packet, AppendTo[messages, packet["Data"]]; Null],
                "Closed" -> Function[packet,
                    cleaned = MissingQ[handler["Buffer"]["Lookup", First[packet["ClosedSocket"]]]];
                    Close[server]
                ],
                "Logger" -> Function[packet,
                    If[packet["Event"] === "Received" && !packet["Completed"],
                        buffered = !MissingQ[handler["Buffer"]["Lookup", First[packet["SourceSocket"]]]];
                        Close[server];
                        Close[client]
                    ]
                ]
            ];
            result = TimeConstrained[CSocketsHandle[{server}, handler], 8, "timeout"];
            result = result === Null && messages === {"ab", "cd"} && buffered && cleaned;
            Scan[Close, CSocketObject /@ Complement[Keys[$CSockets], before]];
            result
        ],
        True,
        TestID -> "synchronous-ipv6-tcp-buffering-and-close-cleanup"
    ],
    VerificationTest[
        And @@ Table[
            Module[{server = CSocketOpen["127.0.0.1", 0, "UDP"], events = {}, cleaned = False, result},
                result = Block[{socketsPoll = Function[{ids, timeout, mask}, {{First[ids], First[flag]}}]},
                    CSocketsHandle[{server}, Function[packet,
                        AppendTo[events, packet];
                        cleaned = !KeyExistsQ[$CSockets, First[server]];
                        Null
                    ]]
                ];
                result = result === Null && cleaned && Lookup[events, "Event"] === {Last[flag]} &&
                    !socketValidQ[First[server]];
                Close[server];
                result
            ],
            {flag, {{$POLLHUP, "Closed"}, {$POLLERR, "Error"}, {$POLLNVAL, "Error"}}}
        ],
        True,
        TestID -> "synchronous-terminal-poll-events-close-before-callback"
    ],
    VerificationTest[
        Module[{server, client, handler, nativePoll = socketsPoll, result, before = Keys[$CSockets]},
            server = CSocketOpen["127.0.0.1", 0, "UDP"];
            client = CSocketConnect[server["LocalAddress"]];
            WriteString[client, "pending"];
            handler = CSocketHandler[
                "ReceivedFrom" -> (#DataByteArray&),
                "Logger" -> Function[packet, Close[server]]
            ];
            result = Block[{socketsPoll = Function[{ids, timeout, mask},
                Map[{First[#], BitOr[Last[#], $POLLERR, $POLLHUP]}&, nativePoll[ids, timeout, mask]]
            ]},
                TimeConstrained[CSocketsHandle[{server}, handler], 8, "timeout"]
            ];
            result = result === Null && SocketReadyQ[client, 1] && ReadString[client] === "pending";
            Scan[Close, CSocketObject /@ Complement[Keys[$CSockets], before]];
            result
        ],
        True,
        TestID -> "synchronous-readable-data-drains-before-error-or-hangup"
    ],
    VerificationTest[
        Module[{server = CSocketOpen["127.0.0.1", 0, "UDP"], result, called = False},
            result = TimeConstrained[CSocketsHandle[{server}, Function[called = True]], 0.2, "stopped"];
            result = result === "stopped" && !called && socketValidQ[First[server]] && server["Listener"] === Null;
            Close[server];
            result
        ],
        True,
        TestID -> "synchronous-idle-loop-is-abortable-and-keeps-open-sockets"
    ],
    VerificationTest[
        CSocketsHandle[{}, Function[Null]],
        Null,
        TestID -> "synchronous-empty-socket-list"
    ],
    VerificationTest[
        Quiet[CSocketsHandle[{CSocketObject[-1]}, Function[Null]]],
        $Failed,
        TestID -> "synchronous-rejects-unregistered-sockets"
    ]
}];


End[];


WLJS`CSockets`Private`handleReport
