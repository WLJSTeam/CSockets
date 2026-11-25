Needs["MUnit`"];
Get[FileNameJoin[{DirectoryName[$InputFileName, 2], "Kernel", "CSockets.wl"}]];


TestReport[{
    VerificationTest[
        Module[{server, client, events = {}, accepted, closed, result},
            server = CSocketOpen["127.0.0.1", 0];
            SocketListen[server, (AppendTo[events, #])&];
            client = CSocketConnect["127.0.0.1", server["DestinationPort"], "TCP", "Wait" -> True, "Blocking" -> False];
            Do[Pause[0.02]; If[AnyTrue[events, #["Event"] === "Accepted"&], Break[]], {100}];
            accepted = Lookup[SelectFirst[events, #["Event"] === "Accepted"&, <||>], "AcceptedSocket", $Failed];
            result = MatchQ[accepted, CSocketObject[_Integer]] && (client["BlockingMode"] === "NonBlocking");
            Close[client];
            Do[Pause[0.02]; If[AnyTrue[events, #["Event"] === "Closed"&], Break[]], {100}];
            closed = Lookup[SelectFirst[events, #["Event"] === "Closed"&, <||>], "ClosedSocket", $Failed];
            result = result && closed === accepted && accepted["State"] === "Closed";
            Close[server];
            result && !KeyExistsQ[WLJS`CSockets`Private`$ownedSocketLists, First[server]] &&
                WLJS`CSockets`$CSockets[First[server]]["State"] === "Closed"
        ],
        True,
        TestID -> "async-peer-close-updates-metadata-and-owned-list-is-released"
    ],
    VerificationTest[
        Module[{server, client, events = {}, result},
            server = CSocketOpen["127.0.0.1", 0, "UDP"];
            SocketListen[server, (AppendTo[events, #]; Close[server])&];
            client = CSocketConnect["127.0.0.1", server["DestinationPort"], "UDP", "Wait" -> True];
            BinaryWrite[client, ByteArray[{}]];
            Do[Pause[0.02]; If[Length[events] > 0, Break[]], {100}];
            result = Length[events] === 1 && events[[1]]["Event"] === "ReceivedFrom" &&
                events[[1]]["DataBytes"] === {} && server["State"] === "Closed";
            Close[client];
            Close[server];
            Pause[0.1];
            result && Length[events] === 1 && !KeyExistsQ[WLJS`CSockets`Private`$ownedSocketLists, First[server]]
        ],
        True,
        TestID -> "empty-udp-datagram-and-close-inside-callback"
    ],
    VerificationTest[
        Module[{server, client, accepted, id, result, addresses},
            server = CSocketOpen["127.0.0.1", 0];
            client = CSocketConnect["127.0.0.1", server["DestinationPort"], "TCP", "Wait" -> True];
            id = WLJS`CSockets`Private`socketAccept[First[server], False];
            accepted = WLJS`CSockets`Private`registerSocket[id, "TCP", "Accepted", True];
            addresses = accepted["Addresses"];
            result = MatchQ[server, CSocketObject[_Integer]] && server["Role"] === "Binded" &&
                client["Role"] === "Connected" && accepted["Role"] === "Accepted" &&
                server["Protocol"] === "TCP" && (client["BlockingMode"] === "Blocking") &&
                addresses === Reverse[client["Addresses"]] && server["Addresses"][[2]] === "";
            BinaryWrite[client, ByteArray[{1, 2, 3, 4, 5}]];
            result = result && WLJS`CSockets`Private`socketRecv[id, ByteArray[{0, 0}]] === ByteArray[{1, 2}] &&
                SocketReadyQ[accepted, 1] && SocketWaitNext[accepted] === {{id, 1}} &&
                SocketReadMessage[accepted] === ByteArray[{3, 4, 5}];
            Scan[Close, {accepted, client, server}];
            result && server["State"] === "Closed" && server["Addresses"][[1]] =!= "" && Close[server] === Null
        ],
        True,
        TestID -> "tcp-objects-use-id-and-wl-metadata-with-both-endpoints"
    ],
    VerificationTest[
        Module[{id, socket, task, result},
            id = WLJS`CSockets`Private`createSocket["IPv4", "UDP"];
            socket = CSocketObject[id];
            WLJS`CSockets`Private`bind[id, "127.0.0.1", 0];
            task = SocketListen[{socket}, Function[Null]];
            RemoveAsynchronousTask[task];
            Pause[1.1];
            result = WLJS`CSockets`Private`socketValidQ[id] && KeyExistsQ[$CSockets, id];
            Close[socket];
            result && !KeyExistsQ[$CSockets, id]
        ],
        True,
        TestID -> "cancel-listener-releases-private-list-without-closing-sockets"
    ],
    VerificationTest[
        Quiet[CSocketConnect["localhost", 80, "TCP", "Wait" -> "invalid"]],
        $Failed,
        TestID -> "invalid-options-rejected-before-native-call"
    ],
    VerificationTest[
        Module[{server, client, result},
            server = CSocketOpen["127.0.0.1", 0];
            client = CSocketConnect["127.0.0.1", server["DestinationPort"]];
            result = MatchQ[client, CSocketObject[_Integer]] && client["Role"] === "Connected" && (client["BlockingMode"] === "Blocking");
            Scan[Close, {client, server}];
            result
        ],
        True,
        TestID -> "default-connect-registers-role-and-final-mode"
    ],
    VerificationTest[
        Block[{
            WLJS`CSockets`Private`socketSend = Function[{id, bytes, length}, {id, Length[bytes], length}],
            WLJS`CSockets`$CSockets = <||>
        },
            WriteString[CSocketObject[42], "hi"]
        ],
        {42, 2, 2},
        TestID -> "writes-pass-only-numeric-id"
    ]
}]
