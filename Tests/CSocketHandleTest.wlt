Needs["MUnit`"];


Get[FileNameJoin[{DirectoryName[$InputFileName, 2], "Kernel", "CSockets.wl"}]];


Begin["WLJS`CSockets`Private`"];


CSocketHandleTest::native =
"Injected poll failure.";


runHandleTest[socket_CSocketObject, handler_] :=
runHandleTest[{socket -> handler}];


runHandleTest[bindings_Association] :=
runHandleTest[Normal[bindings]];


runHandleTest[bindings_List] :=
Module[{socketIds = First /@ Keys[Association[bindings]], parked, events},
    parked = AssociationMap[$CSockets[#, "Listener"]&, Complement[Keys[$CSockets], socketIds]];
    KeyValueMap[(#1["Handler"] = #2)&, Association[bindings]];

    Internal`WithLocalSettings[
        Scan[($CSockets[#, "Listener"] = AsynchronousTaskObject[0, 0])&, Keys[parked]],
        While[socketIds =!= {},
            events = CSocketHandle[];
            If[!ListQ[events], Return[events]];
            socketIds = Select[
                Union[socketIds, Cases[Lookup[events, "AcceptedSocket"], CSocketObject[socketId_Integer] :> socketId]],
                KeyExistsQ[$CSockets, #]&
            ];
        ],
        KeyValueMap[If[KeyExistsQ[$CSockets, #1], $CSockets[#1, "Listener"] = #2]&, parked]
    ]
];


handleReport = TestReport[{
    VerificationTest[
        Module[{
            servers, clients, handlers, result, inherited = True,
            labels = {"one", "two"},
            events = <|"one" -> {}, "two" -> {}|>,
            replies = <|"one" -> {}, "two" -> {}|>,
            before = Keys[$CSockets]
        },
            servers = Table[CSocketOpen["127.0.0.1", 0], {2}];
            clients = CSocketConnect[#["LocalAddress"]]& /@ servers;
            WriteString[clients[[1]], "ab"];
            WriteString[clients[[2]], "xyz"];
            handlers = Table[
                With[{
                    label = labels[[index]], server = servers[[index]],
                    client = clients[[index]], expectedLength = index + 1
                },
                    CSocketHandler[
                        "Accumulator" -> Function[expectedLength],
                        "Deserializer" -> ByteArrayToString,
                        "Serializer" -> Function[value, label <> ":" <> value],
                        "Received" -> (ToUpperCase[#Data]&),
                        "Accepted" -> Function[packet,
                            inherited = inherited && $CSockets[First[packet["AcceptedSocket"]], "Handler"] === packet["Handler"];
                            Close[server]
                        ],
                        "Logger" -> Function[packet,
                            AppendTo[events[label], packet["Event"]];

                            If[packet["Event"] === "Received",
                                AppendTo[replies[label], If[SocketReadyQ[client, 1], ReadString[client], "no reply"]];
                                Close[client]
                            ]
                        ]
                    ]
                ],
                {index, 2}
            ];
            result = TimeConstrained[runHandleTest[MapThread[Rule, {servers, handlers}]], 8, "timeout"];
            result = result === Null && inherited && replies === <|"one" -> {"one:AB"}, "two" -> {"two:XYZ"}|> &&
                AllTrue[Values[events], # === {"Accepted", "Received", "Closed"}&];
            Scan[Close, CSocketObject /@ Complement[Keys[$CSockets], before]];
            result
        ],
        True,
        TestID -> "synchronous-tcp-connections-inherit-distinct-server-handlers"
    ],
    VerificationTest[
        Module[{servers, clients, firstHandler, secondHandler, routes = {}, result, before = Keys[$CSockets]},
            servers = CSocketOpen[#, 0, "UDP"]& /@ {"127.0.0.1", "::1"};
            clients = CSocketConnect[#["LocalAddress"]]& /@ servers;
            Scan[WriteString[#, "ping"]&, clients];
            WriteString[clients[[2]], "stop"];
            firstHandler = CSocketHandler[
                "Deserializer" -> ByteArrayToString,
                "ReceivedFrom" -> ("one:" <> #Data&),
                "Logger" -> Function[packet,
                    AppendTo[routes, {"one", packet["SourceSocket"]}];
                    Close[servers[[1]]]
                ]
            ];
            secondHandler = Function[packet,
                AppendTo[routes, {"two", packet["SourceSocket"]}];

                If[packet["Data"] === "stop",
                    Close[servers[[2]]]; Null,
                    "two:" <> packet["Data"]
                ]
            ];
            result = TimeConstrained[runHandleTest[{
                servers[[1]] -> firstHandler,
                servers[[2]] -> secondHandler
            }], 8, "timeout"];
            result = result === Null &&
                Sort[routes] === Sort[{{"one", servers[[1]]}, {"two", servers[[2]]}, {"two", servers[[2]]}}] &&
                SocketReadyQ[clients[[1]], 1] && ReadString[clients[[1]]] === "one:ping" &&
                SocketReadyQ[clients[[2]], 1] && ReadString[clients[[2]]] === "two:ping" && !SocketReadyQ[clients[[2]]];
            Scan[Close, CSocketObject /@ Complement[Keys[$CSockets], before]];
            result
        ],
        True,
        TestID -> "synchronous-udp-servers-route-to-object-and-function-handlers"
    ],
    VerificationTest[
        Module[{server, client, packets = {}, result},
            server = CSocketOpen["127.0.0.1", 0, "UDP"];
            client = CSocketConnect[server["LocalAddress"]];
            $CSockets[First[server], "Buffer"] = ByteArray[{0, 0, 0}];
            BinaryWrite[client, ByteArray[{1, 2}]];
            BinaryWrite[client, ByteArray[{3, 4, 5}]];

            result = TimeConstrained[runHandleTest[server, Function[packet,
                AppendTo[packets, packet];
                If[Length[packets] === 2, Close[server]];
                Null
            ]], 5, $Aborted];

            Close[client];
            result === Null && Lookup[packets, "DataByteArray"] === {ByteArray[{1, 2}], ByteArray[{3, 4, 5}]}
        ],
        True,
        TestID -> "synchronous-events-keep-the-valid-prefix-across-buffer-reuse"
    ],
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
            result = TimeConstrained[runHandleTest[{server -> handler}], 8, "timeout"];
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
            result = TimeConstrained[runHandleTest[Map[# -> handler&, servers]], 8, "timeout"];
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
                result = TimeConstrained[runHandleTest[{managed -> handler}], 8, "timeout"];
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
                "ReceivedFrom" -> (#DataByteArray&),
                "Logger" -> Function[received, packet = received; Close[client]]
            ];
            result = TimeConstrained[runHandleTest[<|client -> handler|>], 8, "timeout"];
            result = result === Null && packet["Event"] === "ReceivedFrom" &&
                packet["Address"] === StringDelete[server["LocalAddress"], StartOfString ~~ "udp://"] &&
                packet["Task"] === Null &&
                SocketReadyQ[server, 1] && Last[SocketReadMessage[server]] === StringToByteArray["hello"];
            Scan[Close, CSocketObject /@ Complement[Keys[$CSockets], before]];
            result
        ],
        True,
        TestID -> "synchronous-connected-udp-event-includes-sender-and-replies-to-peer"
    ],
    VerificationTest[
        Module[{server, client, handler, task, delivered = {}, events, replies, result},
            server = CSocketOpen["127.0.0.1", 0, "UDP"];
            client = CSocketConnect[server["LocalAddress"]];
            handler = Function[event,
                AppendTo[delivered, event];
                event["DataByteArray"]
            ];
            task = SocketListen[server, handler];
            WriteString[client, "ping"];
            Do[
                Pause[0.02];
                If[delivered =!= {}, Break[]],
                {150}
            ];
            RemoveAsynchronousTask[task];
            Pause[1.1];
            replies = {If[SocketReadyQ[client, 1], ReadString[client], $Failed]};

            WriteString[client, "ping"];
            events = waitEvents[{First[server]}, 1];
            AppendTo[replies, If[SocketReadyQ[client, 1], ReadString[client], $Failed]];
            result = Length[delivered] === 2 && events === {Last[delivered]} &&
                delivered[[1]]["Task"] === task && delivered[[2]]["Task"] === Null &&
                SameQ @@ (KeyDrop[#, {"Timestamp", "Task"}]& /@ delivered) && replies === {"ping", "ping"};
            Scan[Close, {client, server}];
            result
        ],
        True,
        TestID -> "sync-and-async-deliver-matching-events-and-use-the-same-function-handler"
    ],
    VerificationTest[
        Module[{server, client, count = 0, result, before = Keys[$CSockets]},
            server = CSocketOpen["127.0.0.1", 0, "UDP"];
            client = CSocketConnect[server["LocalAddress"]];
            WriteString[client, "first"];
            WriteString[client, "second"];
            result = TimeConstrained[runHandleTest[{
                server -> Function[Throw["wrong handler"]],
                server -> Function[packet,
                    count++;

                    If[count === 1,
                        "reply",
                        Close[server]; Null
                    ]
                ]
            }], 8, "timeout"];
            result = result === Null && count === 2 && SocketReadyQ[client, 1] && ReadString[client] === "reply" &&
                !SocketReadyQ[client];
            Scan[Close, CSocketObject /@ Complement[Keys[$CSockets], before]];
            result
        ],
        True,
        TestID -> "synchronous-function-response-null-and-duplicate-input"
    ],
    VerificationTest[
        Module[{server = CSocketOpen["127.0.0.1", 0, "UDP"], called = False, result},
            result = Block[{socketsPoll = Function[Null, Message[CSocketHandleTest::native]; {}]},
                TimeConstrained[runHandleTest[server, Function[called = True]], 4, "timeout"]
            ];
            result = MatchQ[result, Failure["socketsPoll", _Association]] && !called && socketValidQ[First[server]];
            Close[server];
            result
        ],
        True,
        {CSocketHandleTest::native, poll::fail},
        TestID -> "synchronous-poll-message-reaches-public-catch"
    ],
    VerificationTest[
        Module[{server = CSocketOpen["127.0.0.1", 0, "UDP"], called = False, result},
            result = Block[{
                socketsPoll = Function[{ids, timeout, mask}, {{First[ids], $POLLIN}}],
                socketRecvFromInto = Function[Null, $Failed]
            },
                TimeConstrained[runHandleTest[server, Function[called = True]], 4, "timeout"]
            ];
            result = MatchQ[result, Failure["socketRecvFrom", _Association]] && !called && socketValidQ[First[server]];
            Close[server];
            result
        ],
        True,
        {read::fail},
        TestID -> "synchronous-read-error-reaches-public-catch"
    ],
    VerificationTest[
        Module[{server, client, result},
            server = CSocketOpen["127.0.0.1", 0, "UDP"];
            client = CSocketConnect[server["LocalAddress"]];
            WriteString[client, "ping"];
            result = Block[{socketSendToRange = Function[Null, 0]},
                TimeConstrained[runHandleTest[server, Function["pong"]], 4, "timeout"]
            ];
            Scan[Close, {client, server}];
            MatchQ[result, Failure["socketSendTo", KeyValuePattern["BytesSent" -> 0]]]
        ],
        True,
        {write::fail},
        TestID -> "synchronous-reply-error-reaches-public-catch"
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
            result = TimeConstrained[runHandleTest[{server -> handler}], 8, "timeout"];
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
                    runHandleTest[{server -> Function[packet,
                        AppendTo[events, packet];
                        cleaned = !KeyExistsQ[$CSockets, First[server]];
                        Null
                    ]}]
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
        Module[{servers, events = {}, result},
            servers = Table[CSocketOpen["127.0.0.1", 0, "UDP"], {2}];
            result = Block[{socketsPoll = Function[{ids, timeout, mask},
                {{First[ids], $POLLERR}, {Last[ids], $POLLHUP}}
            ]},
                runHandleTest[{
                    servers[[1]] -> Function[packet,
                        AppendTo[events, {"one", packet["Event"], packet["ErrorSocket"]}]; Null
                    ],
                    servers[[2]] -> Function[packet,
                        AppendTo[events, {"two", packet["Event"], packet["ClosedSocket"]}]; Null
                    ]
                }]
            ];
            result = result === Null && events === {{"one", "Error", servers[[1]]}, {"two", "Closed", servers[[2]]}};
            Scan[Close, servers];
            result
        ],
        True,
        TestID -> "synchronous-error-and-close-events-use-their-socket-handlers"
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
                TimeConstrained[runHandleTest[{server -> handler}], 8, "timeout"]
            ];
            result = result === Null && SocketReadyQ[client, 1] && ReadString[client] === "pending";
            Scan[Close, CSocketObject /@ Complement[Keys[$CSockets], before]];
            result
        ],
        True,
        TestID -> "synchronous-readable-data-drains-before-error-or-hangup"
    ],
    VerificationTest[
        Module[{server = CSocketOpen["127.0.0.1", 0, "UDP"], client, received = {}, timeouts = {}, first, second, idle,
            nativePoll = socketsPoll, payloads = {ByteArray[{1}], ByteArray[{2}]}},
            client = CSocketConnect[server["LocalAddress"]];
            $CSockets[First[server], "Handler"] = Function[event, AppendTo[received, event["DataByteArray"]]; Null];
            $CSockets[First[client], "Listener"] = AsynchronousTaskObject[0, 0];
            Scan[BinaryWrite[client, #]&, payloads];

            {first, second, idle} = Block[{socketsPoll = Function[{ids, timeout, mask},
                AppendTo[timeouts, {ids, timeout}];
                nativePoll[ids, timeout, mask]
            ]},
                {CSocketHandle[], CSocketHandle[$CSockets], CSocketHandle[]}
            ];
            Scan[Close, {client, server}];
            MemberQ[Attributes[CSocketHandle], HoldFirst] && Options[CSocketHandle] === {} &&
                Length[first] === 1 && Length[second] === 1 && idle === {} && received === payloads &&
                timeouts === ConstantArray[{{First[server]}, 0}, 3]
        ],
        True,
        TestID -> "synchronous-step-polls-once-with-zero-timeout-and-returns-events"
    ],
    VerificationTest[
        Module[{server, client, registry, listenerId, before, accepted, acceptedId, received, closed, handler,
            observed = {}, payload = ByteArray[{42, 0, 255}], reply},
            server = CSocketOpen["127.0.0.1", 0];
            client = CSocketConnect[server["LocalAddress"]];
            listenerId = First[server];
            before = Keys[$CSockets];
            registry = KeyTake[$CSockets, {listenerId}];
            handler = Function[event,
                AppendTo[observed,
                    Switch[event["Event"],
                        "Accepted", event["AcceptedSocket"]["Role"] === "Accepted",
                        "Received", event["SourceSocket"]["Role"] === "Accepted",
                        "Closed", !KeyExistsQ[$CSockets, First[event["ClosedSocket"]]],
                        _, False
                    ]
                ];
                If[event["Event"] === "Received", event["DataByteArray"], Null]
            ];
            registry[listenerId, "Handler"] = handler;
            accepted = First[CSocketHandle[registry]]["AcceptedSocket"];
            acceptedId = First[accepted];
            If[!KeyExistsQ[registry, acceptedId] || Keys[$CSockets] =!= before ||
                registry[acceptedId, "Handler"] =!= handler || server["Handler"] =!= Null,
                Scan[Close, {client, server}];
                Return[False]
            ];

            BinaryWrite[client, payload];
            received = CSocketHandle[registry];
            reply = If[SocketReadyQ[client, 1], ReadByteArray[client], None];
            Close[client];
            closed = CSocketHandle[registry];
            Close[server];
            Lookup[received, "DataByteArray"] === {payload} && reply === payload &&
                Keys[registry] === {listenerId} && Length[closed] === 1 &&
                First[closed]["ClosedSocket"] === accepted &&
                observed === {True, True, True}
        ],
        True,
        TestID -> "synchronous-step-updates-the-held-registry-and-isolates-the-global-registry"
    ],
    VerificationTest[
        Module[{server, client, registry, result, before},
            server = CSocketOpen["127.0.0.1", 0, "UDP"];
            client = CSocketConnect[server["LocalAddress"]];
            before = Keys[$CSockets];
            registry = KeyTake[$CSockets, {First[server]}];
            registry[First[server], "Handler"] = Function[event,
                Close[event["SourceSocket"]];
                Throw[Failure["TestHandler", <||>]]
            ];
            BinaryWrite[client, ByteArray[{1}]];
            Block[{socketClose = Function[Null, Null]},
                result = CSocketHandle[registry]
            ];
            result = result === Failure["TestHandler", <||>] && registry === <||> && Keys[$CSockets] === before;
            Scan[Close, {client, server}];
            result
        ],
        True,
        TestID -> "synchronous-step-keeps-registry-mutations-when-a-handler-throws"
    ],
    VerificationTest[
        Block[{$CSockets = <||>, socketsPoll = Function[Throw["unexpected poll"]]},
            Module[{registry = <||>}, {CSocketHandle[], CSocketHandle[registry]}]
        ],
        {{}, {}},
        TestID -> "synchronous-empty-registry-does-not-poll"
    ],
    VerificationTest[
        Module[{registry = {1}},
            Quiet[CSocketHandle[registry], CSocketHandle::registry]
        ],
        Failure["CSocketHandle", <|"Reason" -> "InvalidRegistry"|>],
        TestID -> "synchronous-step-rejects-invalid-registry"
    ]
}];


End[];


WLJS`CSockets`Private`handleReport
