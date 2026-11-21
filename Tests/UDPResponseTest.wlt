Needs["MUnit`"];
baseDir = DirectoryName[$InputFileName, 2];
Get[FileNameJoin[{baseDir, "Kernel", "CSockets.wl"}]];


TestReport[{
    VerificationTest[
        Block[{
            WLJS`CSockets`Private`socketSend = Function[{row, bytes, length}, {"TCP", Normal[bytes]}],
            WLJS`CSockets`Private`socketSendTo = Function[{row, host, port, bytes}, {"UDP", host <> ":" <> port, Normal[bytes]}]
        },
            With[{
                packet = <|"SourceSocket" -> CSocketObject[42]|>,
                address = "127.0.0.1:9000"
            },
                {
                    WLJS`CSockets`Private`sendResponse[Append[packet, "Result" -> "ok"]],
                    WLJS`CSockets`Private`sendResponse[Join[packet, <|"Address" -> address, "Result" -> "ok"|>]],
                    WLJS`CSockets`Private`sendResponse[Join[packet, <|"Address" -> address, "Result" -> Null|>]]
                }
            ]
        ],
        {{"TCP", {111, 107}}, {"UDP", "127.0.0.1:9000", {111, 107}}, Null},
        TestID -> "response-selects-send-path-by-address-field"
    ],
    VerificationTest[
        Module[{server, clients, list, task, handler, exchange, result, address},
            server = CSocketOpen["127.0.0.1", 0, "UDP"];
            clients = Table[CSocketConnect["127.0.0.1", server["DestinationPort"], "UDP", "Wait" -> True], {2}];
            list = CSocketList[{server}];
            handler = CSocketHandler[
                "ReceivedFrom" -> (Switch[First[#["DataBytes"]],
                    1, "Привет",
                    2, ByteArray[{0, 128, 255}],
                    3, ByteArray[{}],
                    4, Null
                ]&)
            ];
            task = SocketListen[list, handler];

            exchange[client_CSocketObject, request_Integer, expected_ByteArray] :=
            (
                BinaryWrite[client, ByteArray[{request}]];
                Do[Pause[0.02]; If[TrueQ[SocketReadyQ[client]], Break[]], {100}];
                TrueQ[SocketReadyQ[client]] && With[{received = SocketReadMessage[client]},
                    MatchQ[received, {(_NumericArray | {}), _String}] && ByteArray[received[[1]]] === expected &&
                        ToExpression[Last[WLJS`CSockets`Private`splitAddress[received[[2]]]]] === server["DestinationPort"]
                ]
            );

            result = And[
                exchange[clients[[1]], 1, StringToByteArray["Привет"]],
                exchange[clients[[2]], 2, ByteArray[{0, 128, 255}]],
                exchange[clients[[1]], 3, ByteArray[{}]],
                !TrueQ[SocketReadyQ[clients[[2]]]]
            ];
            BinaryWrite[clients[[2]], ByteArray[{4}]];
            Pause[0.15];
            result = result && !TrueQ[SocketReadyQ[clients[[2]]]];

            address = "127.0.0.1:" <> ToString[clients[[2]]["DestinationPort"]];
            result = result && BinaryWrite[
                server, address, ByteArray[{42}]
            ] === 1;
            result = result && TrueQ[SocketReadyQ[clients[[2]], 1]] && With[{received = SocketReadMessage[clients[[2]]]},
                MatchQ[received, {(_NumericArray | {}), _String}] && ByteArray[received[[1]]] === ByteArray[{42}] &&
                    ToExpression[Last[WLJS`CSockets`Private`splitAddress[received[[2]]]]] === server["DestinationPort"]
            ];

            Close[list];
            Scan[Close, clients];
            Close[server];
            Close[list];
            result
        ],
        True,
        TestID -> "udp-handler-replies-to-each-sender-and-explicit-address"
    ],
    VerificationTest[
        Module[{server = CSocketOpen["127.0.0.1", 0, "UDP"], result},
            result = Quiet[WLJS`CSockets`Private`socketSendTo[
                First[server], "invalid", "80", ByteArray[{42}]
            ]];
            Close[server];
            MatchQ[result, _LibraryFunctionError]
        ],
        True,
        TestID -> "udp-reply-rejects-invalid-numeric-host"
    ]
}]
