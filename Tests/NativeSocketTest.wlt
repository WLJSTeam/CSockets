Needs["MUnit`"];
Get[FileNameJoin[{DirectoryName[$InputFileName, 2], "Kernel", "CSockets.wl"}]];
Begin["WLJS`CSockets`Private`"];


nativeSocketReport = TestReport[{
    VerificationTest[
        And @@ (MatchQ[#, _LibraryFunctionError]& /@ Quiet[{
            socketPollLoopCreate[{10}, {}, 1000, $POLLIN],
            socketPollLoopCreate[{}, {}, -2, $POLLIN],
            socketPollLoopCreate[{-1}, {$SOCKETROLETCPBOUND}, 1000, $POLLIN],
            socketPollLoopCreate[{10}, {99}, 1000, $POLLIN]
        }]),
        True,
        TestID -> "poll-loop-rejects-invalid-lengths-timeout-descriptors-and-roles"
    ],
    VerificationTest[
        Module[{task, events = {}},
            task = Internal`CreateAsynchronousTask[
                socketPollLoopCreate,
                {{}, {}, -1, $POLLIN},
                (AppendTo[events, {#2, #3}])&
            ];
            Pause[0.1];
            (* An empty loop may already have been removed by the kernel. *)
            Quiet[RemoveAsynchronousTask[task], RemoveAsynchronousTask::asyncobj];
            events === {}
        ],
        True,
        TestID -> "empty-private-list-exits-without-polling"
    ],
    VerificationTest[
        Module[{receivers, sender, task, events = {}, ports, result},
            receivers = Table[createSocket["IPv4", "UDP"], {2}];
            Scan[bind[#, "127.0.0.1", 0]&, receivers];
            ports = splitAddress[$CSockets[#, "LocalAddress"]]["Port"]& /@ receivers;
            task = SocketListen[CSocketObject /@ receivers, (AppendTo[events, #])&];
            sender = createSocket["IPv4", "UDP"];
            Scan[socketSendTo[sender, "127.0.0.1", ToString[#], ByteArray[{7}]]&, ports];
            Do[Pause[0.02]; If[Length[events] >= 2, Break[]], {150}];
            result = Sort[Lookup[events, "SourceSocket"]] === Sort[CSocketObject /@ receivers] &&
                Lookup[events, "DataBytes"] === {{7}, {7}};
            RemoveAsynchronousTask[task];
            Pause[1.1];
            result = result && AllTrue[receivers, socketValidQ];
            Scan[close, Append[receivers, sender]];
            result
        ],
        True,
        TestID -> "multiple-initial-sockets-share-task-and-survive-cancellation"
    ],
    VerificationTest[
        Module[{id, task, events = {}, result},
            id = createSocket["IPv4", "UDP"];
            bind[id, "127.0.0.1", 0];
            Do[
                task = Internal`CreateAsynchronousTask[
                    socketPollLoopCreate,
                    {{id, id}, {$SOCKETROLEUDPBOUND, $SOCKETROLEUDPBOUND}, 1000, $POLLIN},
                    (AppendTo[events, {#2, #3}])&
                ];
                RemoveAsynchronousTask[task],
                {25}
            ];
            Pause[0.1];
            result = events === {} && socketValidQ[id];
            close[id];
            result
        ],
        True,
        TestID -> "repeated-task-cancellation-releases-private-lists-and-preserves-sockets"
    ],
    VerificationTest[
        Module[{server, clients, task, events = {}, accepted, port, result},
            server = createSocket["IPv4", "TCP"];
            bind[server, "127.0.0.1", 0];
            listen[server];
            port = splitAddress[$CSockets[server, "LocalAddress"]]["Port"];
            task = SocketListen[CSocketObject[server], (AppendTo[events, #])&];
            clients = Table[
                With[{id = createSocket["IPv4", "TCP"]}, connect[id, "127.0.0.1", port]; id],
                {12}
            ];
            Do[Pause[0.02]; If[Count[Lookup[events, "Event"], "Accepted"] === 12, Break[]], {150}];
            accepted = Lookup[Select[events, #["Event"] === "Accepted"&], "AcceptedSocket"];
            result = Length[accepted] === 12;
            Scan[socketSend[#, ByteArray[{8}]]&, clients];
            Do[Pause[0.02]; If[Count[Lookup[events, "Event"], "Received"] === 12, Break[]], {150}];
            result = result && Count[Lookup[events, "Event"], "Received"] === 12;
            Scan[close, clients];
            Do[Pause[0.02]; If[Count[Lookup[events, "Event"], "Closed"] === 12, Break[]], {150}];
            result = result && Count[Lookup[events, "Event"], "Closed"] === 12 &&
                NoneTrue[First /@ accepted, KeyExistsQ[$CSockets, #]&];
            RemoveAsynchronousTask[task];
            Pause[1.1];
            close[server];
            result
        ],
        True,
        TestID -> "private-list-grows-and-prunes-twelve-accepted-connections"
    ]
}];


Print["Native socket: ", nativeSocketReport["TestsSucceededCount"], " passed; ", nativeSocketReport["TestsFailedCount"], " failed"];
If[nativeSocketReport["TestsFailedCount"] > 0, Print[nativeSocketReport["TestsFailed"]]];
End[];
WLJS`CSockets`Private`nativeSocketReport
