(* :Package: *)

BeginPackage["WLJS`CSockets`Handler`", {
    "WLJS`CSockets`Library`"
}];


CSocketHandler::usage =
"CSocketHandler[] mutable handler object.";


CSocketPacketBuffer::usage =
"CSocketPacketBuffer[] packet buffer.";


Begin["`Private`"];


Options[CSocketHandler] = {
    "Selected" :> Function[#Handler[createEventPacket[#]]],             (* packet = <|Handler -> func, Socket -> serverSocket, SocketList -> socketList, Data -> {socketId}|> *)
    "Received" :> Function[Null],                                       (* packet = <|Handler -> func, Socket -> serverSocket, SocketList -> socketList, Data -> stringMessage, DataByteArray -> data|> *)
    "Accepted" :> Function[Append[#SocketList, #SourceSocket]],         (* packet = <|Handler -> func, Socket -> serverSocket, SocketList -> socketList, SourceSocket -> newClientSocket|> *)
    "Closed" :> Function[Close[#SourceSocket]; DeleteMissing[#Data]],   (* packet = <|Handler -> func, Socket -> serverSocket, SocketList -> socketList, SourceSocket -> closedSocket|> *)
    "Error" :> Function[DeleteMissing[#SourceSocket]],                  (* packet = <|Handler -> func, Socket -> serverSocket, SocketList -> socketList, Data -> errorCode|> *)
    "Completed" :> Function[Null]                                       (* packet = <|Handler -> func, Socket -> serverSocket, SocketList -> socketList, Result -> result|> *)
};


With[{store = Language`NewExpressionStore["CSocketHandler"]},

    CSocketHandler[opts: OptionsPattern[{}]] :=
    With[{handler = CSocketHandler[Null]},
        Map[store["put"[handler, #, OptionValue[CSocketHandler, Flatten[{opts}], #]]]&] @ Keys[Options[CSocketHandler]];
        Map[store["put"[handler, #, OptionValue[Flatten[{opts}], #]]]&] @ DeleteCases[Keys[Flatten[{opts}]], Apply[Alternatives] @ Keys[Options[CSocketHandler]]];
        handler
    ];

    (handler_CSocketHandler)[prop_] := store["get"[handler, prop]];

    CSocketHandler /: Set[(handler_CSocketHandler)[prop_], value_] := (store["put"[handler, prop, value]]; value);

    CSocketHandler /: Set[(handler_CSocketHandler)[prop_, key_], value_] := (store["put"[handler, prop, Append[handler[prop], key -> value]]]; value);
];


Unprotect[Set];


(*TODO: replace to MutationHandler*)
Set[(handler_?(Head[#] === CSocketHandler&))[keys__], value_] :=
With[{$handler$ = handler}, $handler$[keys] = value];


Protect[Set];


(handler_CSocketHandler)[packet_Association] /;
KeyExistsQ[packet, "Event"] :=
handler[packet["Event"]][packet];


(handler_CSocketHandler)[packet_Association] /;
Not[KeyExistsQ[packet, "Event"]] && KeyExistsQ[packet, "DataByteArray"] && ByteArrayQ[packet["DataByteArray"]] :=
handler["Received"][packet];


createEventPacket =
Function[With[{timestamp = Now, event = If[{#SourceSocket} === #ReadySockets, "Accepted", "Received"]},
    Module[{nextPacket = <|"Timestamp" :> timestamp, "Event" :> event|>},
        If[event === "Accepted",
            With[{acceptedSocketId = socketAccept[#Socket]},
                nextPacket["SourceSocket"] := SocketObject[acceptedSocketId]
            ],
            With[{receivedData = SocketReadMessage[#ReadySockets[[1]]]},
                nextPacket["DataByteArary"] := receivedData;
                nextPacket["Data"] := ByteArrayToString[receivedData];
                nextPacket["DataBytes"] := Normal[receivedData];
                nextPacket["SourceSocket"] := SocketObject[First[#Data]];
                nextPacket["MultipartCompleted"] := True;
            ]
        ];
        Join[#, nextPacket]
    ]
]];


End[];


EndPackage[];