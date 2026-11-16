Needs["MUnit`"];
baseDir = DirectoryName[$InputFileName, 2];
Get[FileNameJoin[{baseDir, "Kernel", "CSockets.wl"}]];


TestReport[{
    VerificationTest[
        Block[{
            WLJS`CSockets`Private`socketSend = Function[{row, bytes, length}, {"TCP", Normal[bytes]}],
            WLJS`CSockets`Private`socketSendToAddressStorage = Function[{row, address, bytes}, {"UDP", address, Normal[bytes]}]
        },
            With[{
                packet = <|"SourceSocket" -> CSocketObject[{42, 17, 2, 1, 1, 0}]|>,
                address = ByteArray[{9}]
            },
                {
                    WLJS`CSockets`Private`sendResponse[Append[packet, "Result" -> "ok"]],
                    WLJS`CSockets`Private`sendResponse[Join[packet, <|"AddressStorage" -> AddressStorage[address], "Result" -> "ok"|>]],
                    WLJS`CSockets`Private`sendResponse[Join[packet, <|"AddressStorage" -> AddressStorage[address], "Result" -> Null|>]]
                }
            ]
        ],
        {{"TCP", {111, 107}}, {"UDP", ByteArray[{9}], {111, 107}}, Null},
        TestID -> "response-selects-send-path-by-address-field"
    ],
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
                TrueQ[SocketReadyQ[client]] && With[{received = SocketReadMessage[client]},
                    MatchQ[received, {(_NumericArray | {}), _NumericArray}] && ByteArray[received[[1]]] === expected &&
                        AddressStorage[ByteArray[received[[2]]]]["Port"] === server["DestinationPort"]
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

            addressStorage = WLJS`CSockets`Private`socketAddressStorageCreate[
                "127.0.0.1", ToString[clients[[2]]["DestinationPort"]], 2, 2, 17, ""
            ];
            result = result && BinaryWrite[
                server, AddressStorage[addressStorage], ByteArray[{42}]
            ] === 1;
            result = result && TrueQ[SocketReadyQ[clients[[2]], 1]] && With[{received = SocketReadMessage[clients[[2]]]},
                MatchQ[received, {(_NumericArray | {}), _NumericArray}] && ByteArray[received[[1]]] === ByteArray[{42}] &&
                    AddressStorage[ByteArray[received[[2]]]]["Port"] === server["DestinationPort"]
            ];

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
