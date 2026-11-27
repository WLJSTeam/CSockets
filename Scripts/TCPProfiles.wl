(* ::Package:: *)

BeginPackage["WLJS`CSockets`TCPProfiles`", {"WLJS`CSockets`"}];


CSocketTCPConfigure::usage =
"CSocketTCPConfigure[socket, profile] configures a TCP socket and returns it. Profiles are \"Latency\", \"BulkSend\", and \"BulkReceive\". Use CSocketTCPConfigure[socket, \"BulkReceive\", \"Asynchronous\"] for a SocketListen receiver.";


CSocketTCPConfigure::socket =
"Socket `1` must be a registered TCP socket.";


Begin["`Private`"];


$bulkTCPBuffer = 8 * 1024 * 1024;


$bulkReadBuffer = 4 * 1024 * 1024;


$sendBufferOption = If[StringStartsQ[$SystemID, "Linux"], 7, WLJS`CSockets`Private`$SOSNDBUF];


$receiveBufferOption = If[StringStartsQ[$SystemID, "Linux"], 8, WLJS`CSockets`Private`$SORCVBUF];


setTCPOption[socketId_Integer, level_Integer, option_Integer, value_Integer] :=
Check[
    WLJS`CSockets`Private`socketSetOpt[socketId, level, option, value],
    Throw[Failure["socketSetOpt", <|"SocketID" -> socketId, "Level" -> level, "Option" -> option, "Value" -> value|>]]
];


CSocketTCPConfigure[
    socket: CSocketObject[_Integer],
    profile: "Latency" | "BulkSend" | "BulkReceive",
    mode: ("Synchronous" | "Asynchronous"): "Synchronous"
] :=
Catch @ configureTCPSocket[socket, profile, mode];


configureTCPSocket[
    socket: CSocketObject[socketId_Integer],
    profile: "Latency" | "BulkSend" | "BulkReceive",
    mode: "Synchronous" | "Asynchronous"
] :=
With[{metadata = Lookup[$CSockets, socketId, <||>]},
    If[Lookup[metadata, "Protocol"] =!= "TCP",
        Message[CSocketTCPConfigure::socket, socket];
        Throw[Failure["CSocketTCPConfigure", <|"SocketID" -> socketId, "Profile" -> profile|>]]
    ];

    setTCPOption[socketId, WLJS`CSockets`Private`$IPPROTOTCP, WLJS`CSockets`Private`$TCPNODELAY,
        If[profile === "Latency", 1, 0]
    ];

    Switch[profile,
        "BulkSend",
            setTCPOption[socketId, WLJS`CSockets`Private`$SOL, $sendBufferOption, $bulkTCPBuffer],
        "BulkReceive",
            setTCPOption[socketId, WLJS`CSockets`Private`$SOL, $receiveBufferOption, $bulkTCPBuffer];
            If[mode === "Synchronous" && MemberQ[{"Accepted", "Connected"}, Lookup[metadata, "Role"]],
                $CSockets[socketId, "Buffer"] = ByteArray[ConstantArray[0, $bulkReadBuffer]]
            ]
    ];

    socket
];


End[];


EndPackage[];
