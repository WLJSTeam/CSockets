Needs["MUnit`"];
Get[FileNameJoin[{DirectoryName[$InputFileName, 2], "Kernel", "CSockets.wl"}]];


Begin["WLJS`CSockets`Private`"];


report = TestReport[{
    VerificationTest[
        Module[{socket, id, result},
            socket = CSocketObject[createSocket["IPv4", "UDP"]];
            id = First[socket];
            Close[socket];
            result = !KeyExistsQ[$CSockets, id] && !socketValidQ[id];
            result
        ],
        True,
        TestID -> "explicit-close-closes-native-socket-and-removes-registration"
    ],
    VerificationTest[
        Block[{$CSockets = <||>, socketClose, calls = 0, events = {}},
            socketClose[_Integer] := (calls++; Null);
            registerSocket[10];
            $CSockets[10, "Handler"] = Function[event,
                AppendTo[events, {event["ClosedSocket"], KeyExistsQ[$CSockets, 10]}]
            ];
            dispatchPollEvent[AsynchronousTaskObject[1], "Closed", {10}];
            {calls, events, KeyExistsQ[$CSockets, 10]}
        ],
        {0, {{CSocketObject[10], False}}, False},
        TestID -> "closed-event-removes-registration-before-callback-without-native-close"
    ],
    VerificationTest[
        Block[{$CSockets = <||>, socketValidQ, events = {}},
            socketValidQ[_Integer] := False;
            registerSocket[10];
            $CSockets[10, "Handler"] = Function[event,
                AppendTo[events, {event["ErrorCode"], KeyExistsQ[$CSockets, 10]}]
            ];
            dispatchPollEvent[AsynchronousTaskObject[1], "Error", {10, 99}];
            {events, KeyExistsQ[$CSockets, 10]}
        ],
        {{{99, False}}, False},
        TestID -> "invalid-socket-error-removes-registration-and-delivers-error"
    ],
    VerificationTest[
        Block[{$CSockets = <||>, socketValidQ},
            socketValidQ[_Integer] := True;
            registerSocket[10];
            With[{before = $CSockets[10]},
                errorEvent[10];
                $CSockets[10] === before
            ]
        ],
        True,
        TestID -> "recoverable-error-preserves-metadata"
    ],
    VerificationTest[
        Block[{$CSockets = <||>, socketGetAddresses, events = {}},
            socketGetAddresses[20, $SOCKETROLETCPACCEPTED] := {"127.0.0.1:80", "127.0.0.1:90"};
            registerSocket[10, "TCP", "Bound", "NonBlocking"];
            $CSockets[10, "Handler"] = Function[event,
                AppendTo[events, {event["AcceptedSocket"], $CSockets[20, "Role"]}]
            ];
            dispatchPollEvent[AsynchronousTaskObject[1], "Accepted", {10, 20}];
            $CSockets[10, "Handler"] = Function[event, "updated"];
            {
                events, $CSockets[20, "Addresses"], $CSockets[20, "ListenSocket"],
                $CSockets[20, "BlockingMode"], $CSockets[20, "Listener"],
                $CSockets[20, "Handler"][<||>]
            }
        ],
        {
            {{CSocketObject[20], "Accepted"}}, {"127.0.0.1:80", "127.0.0.1:90"},
            CSocketObject[10], "NonBlocking", AsynchronousTaskObject[1], "updated"
        },
        TestID -> "accepted-event-registers-before-callback-and-inherits-handler-dynamically"
    ],
    VerificationTest[
        Block[{$CSockets = <||>, events = {}},
            registerSocket[10];
            $CSockets[10, "Listener"] = AsynchronousTaskObject[1];
            $CSockets[10, "Handler"] = Function[event, AppendTo[events, event["ClosedSocket"]]];
            dispatchPollEvent[AsynchronousTaskObject[1], "Closed", {20}];
            {events, Keys[$CSockets]}
        ],
        {{CSocketObject[20]}, {10}},
        TestID -> "late-close-event-uses-remaining-task-handler"
    ]
}];


Print["Passed: ", report["TestsSucceededCount"], "; failed: ", report["TestsFailedCount"]];
If[report["TestsFailedCount"] > 0,
    Print[report["TestsFailed"]]
];
End[];
If[WLJS`CSockets`Private`report["TestsFailedCount"] > 0, Exit[1]];
