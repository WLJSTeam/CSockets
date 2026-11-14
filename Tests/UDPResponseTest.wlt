Needs["MUnit`"];
baseDir = DirectoryName[$InputFileName, 2];
Get[FileNameJoin[{baseDir, "Kernel", "CSockets.wl"}]];


TestReport[{
    VerificationTest[
        Module[{server, clients, list, task, handler, exchange, result, addressStorage},
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
                TrueQ[SocketReadyQ[client]] && SocketReadMessage[client] === expected
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

            addressStorage = WLJS`CSockets`Private`socketAddressStorageCreate[
                "127.0.0.1", ToString[clients[[2]]["DestinationPort"]], 2, 2, 17, ""
            ];
            result = result && WLJS`CSockets`Private`sendResponse[
                handler, <|"SourceSocket" -> server|>, ByteArray[{42}], addressStorage
            ] === 1;
            result = result && TrueQ[SocketReadyQ[clients[[2]], 1]] && SocketReadMessage[clients[[2]]] === ByteArray[{42}];

            RemoveAsynchronousTask[task];
            Scan[Close, clients];
            Close[server];
            WLJS`CSockets`Private`socketListDelete[First[list]];
            result
        ],
        True,
        TestID -> "udp-handler-replies-to-each-sender-and-explicit-address"
    ],
    VerificationTest[
        Module[{server = CSocketOpen["127.0.0.1", 0, "UDP"], result},
            result = Quiet[WLJS`CSockets`Private`socketSendToAddressStorage[
                First[server], ByteArray[{1}], ByteArray[{42}]
            ]];
            Close[server];
            MatchQ[result, _LibraryFunctionError]
        ],
        True,
        TestID -> "udp-reply-rejects-short-address-storage"
    ]
}]
