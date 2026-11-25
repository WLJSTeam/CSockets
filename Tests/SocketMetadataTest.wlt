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
            Module[{receiver, id, initial, bound, connected, result},
                receiver = CSocketOpen["127.0.0.1", 0, "UDP"];
                id = createSocket["IPv4", "UDP"];
                initial = $CSockets[id];
                bind[id, "127.0.0.1", 0];
                bound = $CSockets[id];
                toNonBlocking[id];
                connect[
                    id,
                    "127.0.0.1",
                    splitAddress[
                        receiver["LocalAddress"]
                    ]["Port"]
                ];
                connected = $CSockets[id];
                result = initial["Role"] === "Unspecified" && initial["BlockingMode"] === "Blocking" && initial["Addresses"] === {"-", "-"} && bound["Role"] === "Bound" && StringStartsQ[
                    bound["LocalAddress"],
                    "udp://127.0.0.1:"
                ] && connected["Role"] === "Connected" && connected["BlockingMode"] === "NonBlocking" && connected["LocalAddress"] === bound["LocalAddress"] && connected["RemoteAddress"] === receiver["LocalAddress"];
                close[id];
                result = result && !KeyExistsQ[$CSockets, id];
                Close[receiver];
                result
            ],
            True,
            TestID -> "metadata-tracks-create-bind-connect-mode-and-close"
        ],
        VerificationTest[
            Module[{server, client, id, metadata, result},
                server = CSocketOpen["127.0.0.1", 0];
                client = CSocketConnect[
                    server["LocalAddress"]
                ];
                id = socketAccept[
                    First[server]
                ];
                registerAcceptedSocket[
                    First[server],
                    id
                ];
                metadata = $CSockets[id];
                result = metadata["Object"] === CSocketObject[id] && metadata["Role"] === "Accepted" && metadata["ListenSocket"] === server && metadata["LocalAddress"] === client["RemoteAddress"] && metadata["RemoteAddress"] === client["LocalAddress"];
                Scan[
                    Close,
                    {CSocketObject[id], client, server}
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
