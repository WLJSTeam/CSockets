Needs["MUnit`"];


Needs["CCompilerDriver`"];


Get[
    FileNameJoin[
        {DirectoryName[$InputFileName, 2], "Kernel", "CSockets.wl"}
    ]
];


$nativeLibrary = WLJS`CSockets`Private`$library;


$nativeCreate = LibraryFunctionLoad[$nativeLibrary, "socketCreate", {Integer, Integer}, Integer];


$nativeBind = LibraryFunctionLoad[
    $nativeLibrary,
    "socketBind",
    {Integer, "UTF8String", "UTF8String"},
    "Void"
];


$nativeAddresses = LibraryFunctionLoad[$nativeLibrary, "socketGetAddresses", {Integer, Integer}, "DataStore"];


$nativeClose = LibraryFunctionLoad[$nativeLibrary, "socketClose", {Integer}, "Void"];


$nativeSendTo = LibraryFunctionLoad[
    $nativeLibrary,
    "socketSendTo",
    {
        Integer,
        "UTF8String",
        "UTF8String",
        {"ByteArray", "Shared"}
    },
    Integer
];


$nativeNonblocking = LibraryFunctionLoad[$nativeLibrary, "socketSetNonBlockingMode", {Integer}, "Void"];


$nativeRecvFrom = LibraryFunctionLoad[
    $nativeLibrary,
    "socketRecvFrom",
    {
        Integer,
        {"ByteArray", "Shared"}
    },
    "DataStore"
];


$nativeCheck = LibraryFunctionLoad[$nativeLibrary, "socketsCheck", {{Integer, 1}}, {Integer, 1}];


$nativeListen = LibraryFunctionLoad[$nativeLibrary, "socketListen", {Integer, Integer}, "Void"];


$nativeConnect = LibraryFunctionLoad[
    $nativeLibrary,
    "socketConnect",
    {Integer, "UTF8String", "UTF8String"},
    "Void"
];


$nativeAccept = LibraryFunctionLoad[$nativeLibrary, "socketAccept", {Integer}, Integer];


$nativeSend = LibraryFunctionLoad[
    $nativeLibrary,
    "socketSend",
    {
        Integer,
        {"ByteArray", "Shared"}
    },
    Integer
];


$nativeRecv = LibraryFunctionLoad[
    $nativeLibrary,
    "socketRecv",
    {
        Integer,
        {"ByteArray", "Shared"}
    },
    "ByteArray"
];


$shareLibrary = CreateLibrary[
    {
        FileNameJoin[
            {DirectoryName[$InputFileName, 2], "Tests", "OwnershipProbe.c"}
        ]
    },
    "array_socket_shares",
    "TargetDirectory" -> $TemporaryDirectory
];


$nativeShares = LibraryFunctionLoad[$shareLibrary, "arrayShares", {{"ByteArray", "Shared"}}, Integer];


TestReport[
    {
        VerificationTest[
            Module[{
                socket,
                bytes = ByteArray[{1}],
                before,
                result
            },
                socket = $nativeCreate[2, 17];
                before = $nativeShares[bytes];
                Do[
                    Quiet[
                        $nativeSendTo[socket, "invalid", "1", bytes]
                    ],
                    {10}
                ];
                result = $nativeShares[bytes] === before;
                $nativeClose[socket];
                result
            ],
            True,
            TestID -> "byte-shares-released-on-address-error"
        ],
        VerificationTest[
            Module[{
                server,
                client,
                accepted,
                port,
                bytes = ByteArray[{0, 128, 255}],
                buffer,
                before,
                result
            },
                server = $nativeCreate[2, 6];
                client = $nativeCreate[2, 6];
                $nativeBind[server, "127.0.0.1", "0"];
                $nativeListen[server, 8];
                port = Last[
                    StringSplit[
                        First[
                            $nativeAddresses[server, 1]
                        ],
                        ":"
                    ]
                ];
                $nativeConnect[client, "127.0.0.1", port];
                accepted = $nativeAccept[server];
                $nativeNonblocking[accepted];
                buffer = ByteArray[
                    ConstantArray[0, 32]
                ];
                before = {$nativeShares[bytes], $nativeShares[buffer]};
                result = $nativeSend[client, bytes] === 3 && $nativeRecv[accepted, buffer] === bytes;
                result = result && {$nativeShares[bytes], $nativeShares[buffer]} === before;
                Scan[$nativeClose, {accepted, client, server}];
                result
            ],
            True,
            TestID -> "TCP-copy-and-byte-share-release"
        ],
        VerificationTest[
            $nativeCheck[{}],
            {},
            TestID -> "empty-sockets-check"
        ],
        VerificationTest[
            $nativeCheck[{0, 1, -1}],
            {0, 1},
            TestID -> "socket-descriptor-conversion"
        ],
        VerificationTest[
            Module[{
                server,
                client,
                address,
                port,
                sent,
                received,
                payload = ByteArray[{0, 128, 255}]
            },
                server = $nativeCreate[2, 17];
                client = $nativeCreate[2, 17];
                $nativeBind[server, "127.0.0.1", "0"];
                $nativeNonblocking[server];
                address = $nativeAddresses[server, 5];
                port = Last[
                    StringSplit[
                        First[address],
                        ":"
                    ]
                ];
                sent = $nativeSendTo[client, "127.0.0.1", port, payload];
                received = $nativeRecvFrom[
                    server,
                    ByteArray[
                        ConstantArray[0, 32]
                    ]
                ];
                Scan[$nativeClose, {client, server}];
                sent === 3 && Normal[
                    Last[received]
                ] === Normal[payload]
            ],
            True,
            TestID -> "UDP-received-byte-array-copy"
        ]
    }
]
