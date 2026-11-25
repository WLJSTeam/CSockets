Needs["MUnit`"];


Get[
    FileNameJoin[
        {DirectoryName[$InputFileName, 2], "Kernel", "CSockets.wl"}
    ]
];


Begin["WLJS`CSockets`Private`"];


report = TestReport[
    {
        VerificationTest[
            splitAddress /@ {"127.0.0.1:80", "[::1]:8080", "udp://[fe80::1%3]:0", "[fe80::1%eth0]:123"},
            {
                <|
                    "Host" -> "127.0.0.1",
                    "Port" -> 80,
                    "Protocol" -> "TCP",
                    "Family" -> "IPv4"
                |>,
                <|
                    "Host" -> "::1",
                    "Port" -> 8080,
                    "Protocol" -> "TCP",
                    "Family" -> "IPv6"
                |>,
                <|
                    "Host" -> "fe80::1%3",
                    "Port" -> 0,
                    "Protocol" -> "UDP",
                    "Family" -> "IPv6"
                |>,
                <|
                    "Host" -> "fe80::1%eth0",
                    "Port" -> 123,
                    "Protocol" -> "TCP",
                    "Family" -> "IPv6"
                |>
            },
            TestID -> "split-address-preserves-protocol-family-and-scope"
        ],
        VerificationTest[
            And @@ Table[
                !addressQ[address] && splitAddress[address] === $Failed,
                {
                    address,
                    {
                        "invalid",
                        "::1:80",
                        "[::1:80",
                        "::1]:80",
                        "[127.0.0.1]:80",
                        "[::1]:-1",
                        "[::1]:65536",
                        "[::1]:1.5",
                        "[::1%]:80",
                        "[::1%3%4]:80",
                        "[::1]:80junk",
                        "http://[::1]:80",
                        "junk udp://[::1]:80"
                    }
                }
            ],
            True,
            TestID -> "validator-and-parser-reject-malformed-endpoints"
        ],
        VerificationTest[
            And @@ Flatten[
                Table[
                    With[{address = protocol <> "://" <> host <> ":8080"},
                        addressQ[address] && splitAddress[address]["Port"] === 8080 && splitAddress[address]["Protocol"] === ToUpperCase[protocol]
                    ],
                    {
                        protocol,
                        {"tcp", "udp", "TCP", "UDP"}
                    },
                    {
                        host,
                        {"127.0.0.1", "[::1]"}
                    }
                ]
            ],
            True,
            TestID -> "schemes-are-accepted-for-ipv4-and-ipv6"
        ],
        VerificationTest[
            And @@ Table[
                Module[{server, client, endpoint, received, reply, result},
                    endpoint = "udp://" <> If[host === "::1",
                        "[::1]",
                        host
                    ] <> ":0";
                    server = CSocketOpen[endpoint];
                    client = CSocketOpen[endpoint];
                    result = And @@ Table[
                        BinaryWrite[
                            client,
                            server["LocalAddress"],
                            bytes
                        ];
                        If[!TrueQ[
                                SocketReadyQ[server, 1]
                            ],
                            False,
                            received = SocketReadMessage[server];
                            received === {StringDrop[client["LocalAddress"], 6], bytes} && BinaryWrite[
                                server,
                                First[received],
                                Last[received]
                            ] === Length[bytes] && TrueQ[
                                SocketReadyQ[client, 1]
                            ] && With[{reply = SocketReadMessage[client]},
                                reply === {StringDrop[server["LocalAddress"], 6], bytes}
                            ]
                        ],
                        {
                            bytes,
                            {
                                ByteArray[{0, 128, 255}],
                                ByteArray[{}]
                            }
                        }
                    ];
                    Scan[Close, {client, server}];
                    result
                ],
                {
                    host,
                    {"127.0.0.1", "::1"}
                }
            ],
            True,
            TestID -> "native-ipv4-ipv6-endpoints-can-be-reused-for-udp-replies"
        ],
        VerificationTest[
            Module[{server, client, accepted, result},
                server = CSocketOpen["tcp://[::1]:0"];
                client = CSocketConnect[
                    server["LocalAddress"]
                ];
                accepted = socketAccept[
                    First[server]
                ];
                result = MatchQ[client, _CSocketObject] && client["Protocol"] === "TCP" && socketConnectedQ[
                    First[client]
                ] && socketConnectedQ[accepted];
                socketClose[accepted];
                Scan[Close, {client, server}];
                result
            ],
            True,
            TestID -> "tcp-connect-accepts-native-ipv6-address-string"
        ],
        VerificationTest[
            AllTrue[
                {
                    {"localhost", "80"},
                    {"127.0.0.1", "http"},
                    {"", "0"}
                },
                Function[pair,
                    Module[{id, result},
                        id = socketCreate[2, 17];
                        result = Quiet[
                            socketBind[
                                id,
                                pair[[1]],
                                pair[[2]]
                            ]
                        ];
                        socketClose[id];
                        MatchQ[result, _LibraryFunctionError]
                    ]
                ]
            ],
            True,
            TestID -> "native-bind-rejects-hostnames-and-service-names"
        ]
    }
];


Print[
    "Address strings: ",
    report["TestsSucceededCount"],
    " passed; ",
    report["TestsFailedCount"],
    " failed"
];


If[report["TestsFailedCount"] > 0,
    Print[
        report["TestsFailed"]
    ]
];


End[];


WLJS`CSockets`Private`report
