Needs["MUnit`"];
baseDir = DirectoryName[$InputFileName, 2];
Get[FileNameJoin[{baseDir, "Kernel", "CSockets.wl"}]];


TestReport[{
    VerificationTest[
        WLJS`CSockets`Private`splitAddress /@ {"127.0.0.1:80", "[::1]:8080", "[fe80::1%3]:0", "invalid", "::1:80"},
        {{"127.0.0.1", "80"}, {"::1", "8080"}, {"fe80::1%3", "0"}, $Failed, $Failed},
        TestID -> "split-numeric-endpoints"
    ],
    VerificationTest[
        And @@ Table[
            Module[{server, client, received, reply, endpoint, result},
                server = CSocketOpen[host, 0, "UDP"];
                client = CSocketConnect[host, server["DestinationPort"], "UDP", "Wait" -> True];
                endpoint = If[host === "::1", "[::1]", host];
                result = And @@ Table[
                    BinaryWrite[client, bytes];
                    If[!TrueQ[SocketReadyQ[server, 1]], False,
                        received = SocketReadMessage[server];
                        received[[2]] === endpoint <> ":" <> ToString[client["DestinationPort"]] &&
                            ByteArray[received[[1]]] === bytes &&
                            BinaryWrite[server, received[[2]], bytes] === Length[bytes] &&
                            TrueQ[SocketReadyQ[client, 1]] &&
                            With[{reply = SocketReadMessage[client]},
                                ByteArray[reply[[1]]] === bytes &&
                                    reply[[2]] === endpoint <> ":" <> ToString[server["DestinationPort"]]
                            ]
                    ],
                    {bytes, {ByteArray[{0, 128, 255}], ByteArray[{}]}}
                ];
                Scan[Close, {client, server}];
                result
            ],
            {host, {"127.0.0.1", "::1"}}
        ],
        True,
        TestID -> "ipv4-ipv6-string-address-udp-roundtrip"
    ],
    VerificationTest[
        AllTrue[{{"localhost", "80"}, {"127.0.0.1", "http"}, {"", "0"}}, Function[pair,
            Module[{row, result},
                row = WLJS`CSockets`Private`socketCreate[2, 17];
                result = Quiet[WLJS`CSockets`Private`socketBind[row, pair[[1]], pair[[2]]]];
                WLJS`CSockets`Private`socketClose[row];
                MatchQ[result, _LibraryFunctionError]
            ]
        ]],
        True,
        TestID -> "bind-rejects-hostnames-and-service-names"
    ]
}]
