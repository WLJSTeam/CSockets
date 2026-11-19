Needs["MUnit`"];
Get[FileNameJoin[{DirectoryName[$InputFileName, 2], "Kernel", "CSockets.wl"}]];


TestReport[{
    VerificationTest[
        MatchQ[Quiet[WLJS`CSockets`Private`socketCreate[2, #]], _LibraryFunctionError]& /@ {0, -1, 1, 4294967302},
        {True, True, True, True},
        TestID -> "create-rejects-unsupported-protocols"
    ],
    VerificationTest[
        Table[
            Module[{server, client, accepted, port, result},
                server = WLJS`CSockets`Private`socketCreate[2, 6];
                WLJS`CSockets`Private`socketBind[server, "127.0.0.1", "0"];
                WLJS`CSockets`Private`socketListen[server, 8];
                port = WLJS`CSockets`Private`socketGetPort[server];
                client = WLJS`CSockets`Private`socketCreate[2, 6];
                WLJS`CSockets`Private`socketConnect[client, "127.0.0.1", ToString[port]];
                accepted = WLJS`CSockets`Private`socketAccept[server, mode];
                result = IntegerQ[server] && IntegerQ[client] && IntegerQ[accepted] &&
                    WLJS`CSockets`Private`socketGetHost[server] === "127.0.0.1" &&
                    WLJS`CSockets`Private`socketConnectedQ[accepted, !mode] &&
                    WLJS`CSockets`Private`socketSend[client, ByteArray[{1, 2, 3}], 3] === 3 &&
                    WLJS`CSockets`Private`socketRecv[accepted, ByteArray[{0, 0, 0}]] === ByteArray[{1, 2, 3}];
                WLJS`CSockets`Private`socketClose[client];
                result = result && !WLJS`CSockets`Private`socketConnectedQ[accepted, !mode];
                Scan[WLJS`CSockets`Private`socketClose, {accepted, server}];
                result
            ],
            {mode, {False, True}}
        ],
        {True, True},
        TestID -> "integer-descriptors-tcp-blocking-and-nonblocking"
    ],
    VerificationTest[
        Module[{receiver, sender, port, result},
            receiver = WLJS`CSockets`Private`socketCreate[2, 17];
            sender = WLJS`CSockets`Private`socketCreate[2, 17];
            WLJS`CSockets`Private`socketBind[receiver, "127.0.0.1", "0"];
            port = WLJS`CSockets`Private`socketGetPort[receiver];
            WLJS`CSockets`Private`socketSetNonBlockingMode[receiver];
            result = MatchQ[Quiet[WLJS`CSockets`Private`socketRecv[receiver, ByteArray[{0}]]], _LibraryFunctionError];
            WLJS`CSockets`Private`socketSetBlockingMode[receiver];
            result = result && WLJS`CSockets`Private`socketSendTo[sender, "127.0.0.1", ToString[port], ByteArray[{4, 5}]] === 2;
            result = result && Normal[First[WLJS`CSockets`Private`socketRecvFrom[receiver, ByteArray[{0, 0}]]]] === {4, 5};
            Scan[WLJS`CSockets`Private`socketClose, {sender, receiver}];
            result
        ],
        True,
        TestID -> "integer-descriptors-udp-and-mode-switching"
    ],
    VerificationTest[
        WLJS`CSockets`Private`socketConnectedQ[-1, True],
        False,
        TestID -> "invalid-descriptor-is-not-connected"
    ]
}]
