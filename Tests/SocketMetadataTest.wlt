Needs["MUnit`"];


Get[
    FileNameJoin[
        {DirectoryName[$InputFileName, 2], "Kernel", "CSockets.wl"}
    ]
];


Begin["WLJS`CSockets`Private`"];


metadataReport = TestReport[
    {
        VerificationTest[
            Module[{receiver, socketId, initial, bound, connected, result},
                receiver = CSocketOpen["127.0.0.1", 0, "UDP"];
                socketId = createSocket["IPv4", "UDP"];
                initial = $CSockets[socketId];
                bind[socketId, "127.0.0.1", 0];
                bound = $CSockets[socketId];
                toNonBlocking[socketId];
                connect[
                    socketId,
                    "127.0.0.1",
                    splitAddress[
                        receiver["LocalAddress"]
                    ]["Port"]
                ];
                connected = $CSockets[socketId];
                result = initial["Role"] === "Unspecified" && initial["BlockingMode"] === "Blocking" && initial["Addresses"] === {"-", "-"} && bound["Role"] === "Bound" && StringStartsQ[
                    bound["LocalAddress"],
                    "udp://127.0.0.1:"
                ] && connected["Role"] === "Connected" && connected["BlockingMode"] === "NonBlocking" && connected["LocalAddress"] === bound["LocalAddress"] && connected["RemoteAddress"] === receiver["LocalAddress"];
                close[socketId];
                result = result && !KeyExistsQ[$CSockets, socketId];
                Close[receiver];
                result
            ],
            True,
            TestID -> "metadata-tracks-create-bind-connect-mode-and-close"
        ],
        VerificationTest[
            Module[{server, client, acceptedSocketId, metadata, result},
                server = CSocketOpen["127.0.0.1", 0];
                client = CSocketConnect[
                    server["LocalAddress"]
                ];
                acceptedSocketId = socketAccept[
                    First[server]
                ];
                registerAcceptedSocket[
                    First[server],
                    acceptedSocketId
                ];
                metadata = $CSockets[acceptedSocketId];
                result = metadata["Object"] === CSocketObject[acceptedSocketId] && metadata["Role"] === "Accepted" && metadata["ListenSocket"] === server && metadata["LocalAddress"] === client["RemoteAddress"] && metadata["RemoteAddress"] === client["LocalAddress"];
                Scan[
                    Close,
                    {CSocketObject[acceptedSocketId], client, server}
                ];
                result
            ],
            True,
            TestID -> "accepted-metadata-populates-parent-and-both-endpoints"
        ],
        VerificationTest[
            Module[{server, result},
                server = CSocketOpen["127.0.0.1", 0, "UDP"];
                result = Block[{socketGetAddresses = Function[Null, Throw["unexpected address lookup"]]},
                    server["LocalAddress"] === $CSockets[
                        First[server],
                        "LocalAddress"
                    ] && server["Protocol"] === "UDP" && Length[
                        server["Addresses"]
                    ] === 2
                ];
                Close[server];
                result
            ],
            True,
            TestID -> "properties-read-stored-metadata"
        ]
    }
];


End[];


WLJS`CSockets`Private`metadataReport
