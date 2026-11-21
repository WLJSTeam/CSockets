Needs["MUnit`"];
Get[FileNameJoin[{DirectoryName[$InputFileName, 2], "Kernel", "CSockets.wl"}]];


Begin["WLJS`CSockets`Private`"];


nativeSocketReport = TestReport[{
    VerificationTest[
        Module[{list, task, events = {}, result},
            list = socketListCreate[{}, {}];
            task = Internal`CreateAsynchronousTask[createSocketsPollLoop, {list, -1, 1}, (AppendTo[events, {#2, #3}])&];
            Pause[0.05];
            RemoveAsynchronousTask[task];
            Pause[0.1];
            result = events === {} && socketListGetAll[list] === {};
            socketListDelete[list];
            result
        ],
        True,
        TestID -> "cancel-infinite-idle-loop-and-release-list"
    ],
    VerificationTest[
        Module[{server, client, accepted, task, events = {}, result},
            server = socketCreate[2, 6];
            client = socketCreate[2, 6];
            socketBind[server, "127.0.0.1", "0"];
            socketListen[server, 8];
            task = Internal`CreateAsynchronousTask[socketsPollAsync, {{server}, 1000000, 1}, (AppendTo[events, {#2, #3}])&];
            socketConnect[client, "127.0.0.1", ToString[socketGetPort[server]]];
            Do[Pause[0.02]; If[Length[events] > 0, Break[]], {100}];
            result = events === {{"Polled", {{{server, 1}}}}};
            socketSetNonBlockingMode[server];
            accepted = socketAccept[server, True];
            result = result && IntegerQ[accepted];
            If[IntegerQ[accepted], socketClose[accepted]];
            Scan[socketClose, {server, client}];
            result
        ],
        True,
        TestID -> "async-tcp-readiness-leaves-accept-to-wl"
    ],
    VerificationTest[
        Module[{a, b, list, result},
            a = socketCreate[2, 17];
            b = socketCreate[2, 6];
            list = socketListCreate[{}, {}];
            socketListAdd[list, a];
            socketListAdd[list, b];
            socketListAdd[list, a];
            result = socketListGetAll[list] === {a, b} && socketsCheck[{a, -1, b}] === {a, b};
            socketClose[a];
            socketListPrune[list];
            result = result && socketListGetAll[list] === {b};
            socketListDelete[list];
            result = result && socketsCheck[{b}] === {b};
            socketClose[b];
            result
        ],
        True,
        TestID -> "lists-contain-unique-ids-prune-closed-and-do-not-own-sockets"
    ],
    VerificationTest[
        {socketsCheck[{}], Dimensions[socketsPoll[{}, 0, 1]]},
        {{}, {0}},
        TestID -> "empty-descriptor-tensors"
    ],
    VerificationTest[
        Module[{receiver, sender, rows, result, addresses},
            receiver = socketCreate[2, 17];
            sender = socketCreate[2, 17];
            socketBind[receiver, "127.0.0.1", "0"];
            addresses = List @@ socketGetAddresses[receiver, 1];
            result = Length[addresses] === 2 && addresses[[2]] === "";
            result = result && socketsPoll[{receiver}, 0, 1] === {};
            socketSendTo[sender, "127.0.0.1", ToString[socketGetPort[receiver]], ByteArray[{7, 8}]];
            rows = socketsPoll[{receiver}, 1000000, 1];
            result = result && rows === {{receiver, 1}};
            result = result && Normal[First[socketRecvFrom[receiver, ByteArray[{0, 0}]]]] === {7, 8};
            Scan[socketClose, {receiver, sender}];
            result
        ],
        True,
        TestID -> "poll-returns-id-event-pairs-without-consuming-udp-data"
    ],
    VerificationTest[
        Module[{receiver, sender, task, events = {}, result},
            receiver = socketCreate[2, 17];
            sender = socketCreate[2, 17];
            socketBind[receiver, "127.0.0.1", "0"];
            task = Internal`CreateAsynchronousTask[
                socketsPollAsync,
                {{receiver}, 1000000, 1},
                (AppendTo[events, {#2, #3}])&
            ];
            socketSendTo[sender, "127.0.0.1", ToString[socketGetPort[receiver]], ByteArray[{9}]];
            Do[Pause[0.02]; If[Length[events] > 0, Break[]], {100}];
            result = events === {{"Polled", {{{receiver, 1}}}}};
            result = result && Normal[First[socketRecvFrom[receiver, ByteArray[{0}]]]] === {9};
            Scan[socketClose, {receiver, sender}];
            result
        ],
        True,
        TestID -> "one-shot-async-reports-id-event-pairs"
    ],
    VerificationTest[
        Module[{receiver, sender, list, task, events = {}, result},
            receiver = socketCreate[2, 17];
            sender = socketCreate[2, 17];
            socketBind[receiver, "127.0.0.1", "0"];
            list = socketListCreate[{}, {}];
            task = Internal`CreateAsynchronousTask[
                createSocketsPollLoop,
                {list, -1, 1},
                (AppendTo[events, {#2, #3}])&
            ];
            socketListAdd[list, receiver];
            socketSendTo[sender, "127.0.0.1", ToString[socketGetPort[receiver]], ByteArray[{10}]];
            Do[Pause[0.02]; If[Length[events] > 0, Break[]], {100}];
            socketListDelete[list];
            Pause[0.1];
            result = Length[events] > 0 && First[events] === {"Polled", {{{receiver, 1}}}};
            result = result && socketsCheck[{receiver}] === {receiver};
            result = result && Normal[First[socketRecvFrom[receiver, ByteArray[{0}]]]] === {10};
            Scan[socketClose, {receiver, sender}];
            result
        ],
        True,
        TestID -> "loop-sees-list-updates-and-survives-list-deletion"
    ],
    VerificationTest[
        Module[{events = {}, task, result},
            task = Internal`CreateAsynchronousTask[socketsPollAsync, {{}, 10000, 1}, (AppendTo[events, {#2, #3}])&];
            Do[Pause[0.02]; If[Length[events] > 0, Break[]], {100}];
            result = Length[events] === 1 && events[[1, 1]] === "Polled" && events[[1, 2, 1]] === {};
            result
        ],
        True,
        TestID -> "async-empty-input-times-out-with-empty-pairs"
    ]
}];


End[];


WLJS`CSockets`Private`nativeSocketReport
