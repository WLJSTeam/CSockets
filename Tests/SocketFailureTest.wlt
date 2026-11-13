Needs["MUnit`"];
baseDir = DirectoryName[$InputFileName, 2];
Get[FileNameJoin[{baseDir, "Kernel", "CSockets.wl"}]];


TestReport[Join[
    Table[
        VerificationTest[
            Block[{
                WLJS`CSockets`$CSockets = <||>,
                closed = 0,
                created = 0,
                WLJS`CSockets`Private`socketAddressStorageCreate = Function[Null, If[stage === "address", $Failed, ByteArray[{}]]],
                WLJS`CSockets`Private`socketCreate = Function[Null, created++; If[stage === "create", $Failed, {42, 6, 1, 0, 1, 0}]],
                WLJS`CSockets`Private`socketBind = Function[Null, If[stage === "bind", $Failed, Null]],
                WLJS`CSockets`Private`socketListen = Function[Null, If[stage === "listen", $Failed, Null]],
                WLJS`CSockets`Private`socketClose = Function[Null, closed++; Null]
            },
                With[{result = CSocketOpen["127.0.0.1", 8080]},
                    {result, closed, created, Length[$CSockets]}
                ]
            ],
            {$Failed, If[MemberQ[{"bind", "listen"}, stage], 1, 0], If[stage === "address", 0, 1], 0},
            {CSocketOpen::open},
            TestID -> ("open-failure-" <> stage)
        ],
        {stage, {"address", "create", "bind", "listen"}}
    ],
    Table[
        VerificationTest[
            Block[{
                WLJS`CSockets`$CSockets = <||>,
                closed = 0,
                created = 0,
                WLJS`CSockets`Private`socketAddressStorageCreate = Function[Null, If[stage === "address", $Failed, ByteArray[{}]]],
                WLJS`CSockets`Private`socketCreate = Function[Null, created++; If[stage === "create", $Failed, {42, 6, 1, 0, 1, 0}]],
                WLJS`CSockets`Private`socketSetNonBlockingMode = Function[Null, If[stage === "nonblocking", $Failed, Null]],
                WLJS`CSockets`Private`socketConnect = Function[Null, If[stage === "connect", $Failed, Null]],
                WLJS`CSockets`Private`socketSetBlockingMode = Function[Null, If[stage === "blocking", $Failed, Null]],
                WLJS`CSockets`Private`socketClose = Function[Null, closed++; Null]
            },
                With[{result = CSocketConnect["127.0.0.1", 8080]},
                    {result, closed, created, Length[$CSockets]}
                ]
            ],
            {$Failed, If[MemberQ[{"nonblocking", "connect", "blocking"}, stage], 1, 0], If[stage === "address", 0, 1], 0},
            {CSocketConnect::connect},
            TestID -> ("connect-failure-" <> stage)
        ],
        {stage, {"address", "create", "nonblocking", "connect", "blocking"}}
    ],
    {
        VerificationTest[
            Module[{server = CSocketOpen["127.0.0.1", 0], result, count},
                count = Length[$CSockets];
                result = CSocketOpen["127.0.0.1", server["DestinationPort"]];
                count = Length[$CSockets] - count;
                Close[server];
                {result, count}
            ],
            {$Failed, 0},
            {CSocketOpen::open},
            TestID -> "occupied-port-reports-failure"
        ],
        VerificationTest[
            Module[{server = CSocketOpen["127.0.0.1", 0], port},
                port = server["DestinationPort"];
                Close[server];
                CSocketConnect["127.0.0.1", port, "TCP", "Wait" -> True]
            ],
            $Failed,
            {CSocketConnect::connect},
            TestID -> "refused-connection-reports-failure"
        ]
    }
]]
