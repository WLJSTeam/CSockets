Needs["MUnit`"];


Get[
    FileNameJoin[
        {DirectoryName[$InputFileName, 2], "Kernel", "CSockets.wl"}
    ]
];


Begin["WLJS`CSockets`Private`"];


SocketFailureTest::native = "Injected native failure.";


failureReport = TestReport[
    {
        VerificationTest[
            Block[{$CSockets = <||>, socketCreate},
                socketCreate[family_Integer, protocol_Integer] :=
                (
                    Message[SocketFailureTest::native];
                    LibraryFunctionError["create", 6]
                );
                Quiet[
                    CSocketOpen["127.0.0.1", 0]
                ] === Failure["socketCreate", <|"AddressFamily" -> "IPv4", "Protocol" -> "TCP"|>] && $CSockets === <||>
            ],
            True,
            TestID -> "creation-error-does-not-register-socket"
        ],
        VerificationTest[
            Module[{server, result, before},
                server = CSocketOpen["127.0.0.1", 0];
                before = Keys[$CSockets];
                result = Quiet[
                    CSocketOpen[
                        "127.0.0.1",
                        splitAddress[
                            server["LocalAddress"]
                        ]["Port"]
                    ]
                ];
                before = MatchQ[result, Failure["socketBind", _Association]] && Keys[$CSockets] === before;
                Close[server];
                before
            ],
            True,
            TestID -> "bind-error-closes-new-socket-and-removes-registration"
        ],
        VerificationTest[
            Module[{server, port, result, before},
                server = CSocketOpen["127.0.0.1", 0];
                port = splitAddress[
                    server["LocalAddress"]
                ]["Port"];
                Close[server];
                before = Keys[$CSockets];
                result = Quiet[
                    CSocketConnect["127.0.0.1", port]
                ];
                MatchQ[result, Failure["socketConnect", _Association]] && Keys[$CSockets] === before
            ],
            True,
            TestID -> "connection-refused-cleans-up-created-socket"
        ],
        VerificationTest[
            Module[{socket, before, result},
                socket = CSocketOpen["127.0.0.1", 0, "UDP"];
                before = $CSockets[
                    First[socket]
                ];
                result = Block[{socketClose},
                    socketClose[id_Integer] :=
                    (
                        Message[SocketFailureTest::native];
                        LibraryFunctionError["close", 6]
                    );
                    Quiet[
                        Close[socket]
                    ]
                ];
                before = result === Failure["socketClose", <|"SocketID" -> First[socket]|>] && $CSockets[
                    First[socket]
                ] === before;
                Close[socket];
                before
            ],
            True,
            TestID -> "failed-close-preserves-registry"
        ]
    }
];


End[];


WLJS`CSockets`Private`failureReport
