(* ::Package:: *)

BeginPackage["WLJS`CSockets`RawEcho`", {"WLJS`CSockets`"}];


CSocketRawEcho::usage =
"CSocketRawEcho[listener, onAccepted, bufferSize] runs a synchronous TCP echo loop. onAccepted receives the native descriptor and defaults to a no-op. bufferSize defaults to 64 KiB.";


Begin["`Private`"];


CSocketRawEcho[
    CSocketObject[listenSocketId_Integer],
    onAccepted_: (Null&),
    bufferSize_Integer: 65536
] :=
Catch @ With[{
    poll = WLJS`CSockets`Private`socketsPoll,
    receive = WLJS`CSockets`Private`socketRecvInto,
    send = WLJS`CSockets`Private`socketSendRange,
    accept = WLJS`CSockets`Private`accept,
    close = WLJS`CSockets`Private`closeDescriptor,
    pollIn = WLJS`CSockets`Private`$POLLIN,
    terminal = BitOr[WLJS`CSockets`Private`$POLLERR, WLJS`CSockets`Private`$POLLHUP, WLJS`CSockets`Private`$POLLNVAL]
},
    If[!TrueQ[0 < bufferSize < 2 ^ 31] ||
        {$CSockets[listenSocketId, "Protocol"], $CSockets[listenSocketId, "Role"]} =!= {"TCP", "Bound"},
        Throw[Failure["CSocketRawEcho", <|"SocketID" -> listenSocketId, "BufferSize" -> bufferSize|>]]
    ];

    Module[{socketIds = {listenSocketId}, buffer = ByteArray[ConstantArray[0, bufferSize]],
        ready, socketId, flags, acceptedSocketId, bytesRead},
        Internal`WithLocalSettings[
            Null,
            While[True,
                ready = Check[poll[socketIds, 10 ^ 6, pollIn], $Failed];
                If[!ListQ[ready], Throw[Failure["socketsPoll", <|"SocketIDs" -> socketIds|>]]];

                Do[
                    {socketId, flags} = row;

                    If[BitAnd[flags, pollIn] != 0,
                        If[socketId === listenSocketId,
                            acceptedSocketId = accept[listenSocketId];
                            AppendTo[socketIds, acceptedSocketId];
                            onAccepted[acceptedSocketId];
                            Continue[]
                        ];

                        bytesRead = receive[socketId, buffer];
                        If[!IntegerQ[bytesRead], Throw[Failure["socketRecvInto", <|"SocketID" -> socketId|>]]];
                        If[bytesRead > 0,
                            If[Check[send[socketId, buffer, 0, bytesRead], $Failed] =!= bytesRead,
                                Throw[Failure["socketSendRange", <|"SocketID" -> socketId, "BytesRequested" -> bytesRead|>]]
                            ];
                            Continue[]
                        ],
                        If[BitAnd[flags, terminal] === 0, Continue[]]
                    ];

                    If[socketId === listenSocketId,
                        Throw[Failure["CSocketRawEcho", <|"SocketID" -> socketId, "PollFlags" -> flags|>]]
                    ];
                    close[socketId];
                    socketIds = DeleteCases[socketIds, socketId],
                    {row, ready}
                ]
            ],
            Scan[(Quiet[Catch[close[#]]])&, Rest[socketIds]]
        ]
    ]
];


End[];


EndPackage[];
