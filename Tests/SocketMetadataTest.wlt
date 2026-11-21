Needs["MUnit`"];
Get[FileNameJoin[{DirectoryName[$InputFileName, 2], "Kernel", "CSockets.wl"}]];


TestReport[{
    VerificationTest[
        Module[{id, receiver, initial, bound, connected, result},
            receiver = CSocketOpen["127.0.0.1", 0, "UDP"];
            id = WLJS`CSockets`Private`createSocket[2, "UDP"];
            initial = $CSockets[id];
            WLJS`CSockets`Private`bindSocket[id, "127.0.0.1", 0];
            bound = $CSockets[id];
            WLJS`CSockets`Private`setSocketBlocking[id, False];
            WLJS`CSockets`Private`connectSocket[id, "127.0.0.1", receiver["DestinationPort"]];
            connected = $CSockets[id];
            result = initial["Role"] === "Undefined" && initial["BlockingMode"] === "Blocking" &&
                initial["LocalAddress"] === "" && initial["RemoteAddress"] === "" &&
                bound["Role"] === "Binded" && StringStartsQ[bound["LocalAddress"], "127.0.0.1:"] &&
                bound["LocalAddress"] =!= "127.0.0.1:0" && bound["RemoteAddress"] === "" &&
                connected["Role"] === "Connected" && connected["BlockingMode"] === "NonBlocking" &&
                connected["LocalAddress"] === bound["LocalAddress"] &&
                connected["RemoteAddress"] === $CSockets[First[receiver]]["LocalAddress"];
            Close[CSocketObject[id]];
            result = result && $CSockets[id]["State"] === "Closed" && $CSockets[id]["LocalAddress"] === bound["LocalAddress"];
            Close[receiver];
            result
        ],
        True,
        TestID -> "metadata-mutates-immediately-after-create-bind-connect-mode-and-close"
    ],
    VerificationTest[
        Module[{server, client, id, metadata, result},
            server = CSocketOpen["127.0.0.1", 0];
            client = CSocketConnect["127.0.0.1", server["DestinationPort"], "TCP", "Wait" -> True];
            id = WLJS`CSockets`Private`acceptSocket[First[server], True];
            metadata = $CSockets[id];
            result = metadata["Object"] === CSocketObject[id] && metadata["Role"] === "Accepted" &&
                metadata["BlockingMode"] === "Blocking" && metadata["State"] === "Alive" &&
                metadata["ListenSocket"] === server &&
                metadata["LocalAddress"] === $CSockets[First[client]]["RemoteAddress"] &&
                metadata["RemoteAddress"] === $CSockets[First[client]]["LocalAddress"];
            Scan[Close, {CSocketObject[id], client, server}];
            result
        ],
        True,
        TestID -> "accept-registers-both-addresses-and-parent-before-event-delivery"
    ],
    VerificationTest[
        Module[{id, before, failures, result},
            id = WLJS`CSockets`Private`createSocket[2, "UDP"];
            before = $CSockets[id];
            failures = {
                WLJS`CSockets`Private`bindSocket[id, "invalid", 0],
                WLJS`CSockets`Private`connectSocket[id, "invalid", 80]
            };
            result = failures === {$Failed, $Failed} && $CSockets[id] === before;
            Block[{WLJS`CSockets`Private`socketSetNonBlockingMode = Function[Null, $Failed]},
                result = result && WLJS`CSockets`Private`setSocketBlocking[id, False] === $Failed && $CSockets[id] === before
            ];
            Block[{WLJS`CSockets`Private`socketClose = Function[Null, $Failed]},
                result = result && Close[CSocketObject[id]] === $Failed && $CSockets[id] === before
            ];
            Close[CSocketObject[id]];
            result
        ],
        True,
        TestID -> "failed-operations-do-not-mutate-metadata"
    ],
    VerificationTest[
        Module[{server, result},
            server = CSocketOpen["127.0.0.1", 0, "UDP"];
            result = Block[{WLJS`CSockets`Private`socketGetAddresses = Function[Null, $Failed]},
                server["LocalAddress"] === $CSockets[First[server]]["LocalAddress"] &&
                    server["DestinationPort"] > 0 && server["Host"] === "127.0.0.1"
            ];
            Close[server];
            result
        ],
        True,
        TestID -> "address-accessors-read-eagerly-populated-registry"
    ]
}]
