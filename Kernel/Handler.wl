(* :Package: *)

BeginPackage["WLJS`CSockets`Handler`"];


CSocketHandler::usage =
"CSocketHandler[] mutable handler object.";


Begin["`Private`"];


Options[CSocketHandler] = {
    "Selected" :> Function[Null],
    "Received" :> Function[Null],
    "Accepted" :> Function[Append[#Data, #SourceSocket]],
    "Closed" :> Function[Close[#SourceSocket]; DeleteMissing[#Data]],
    "Error" :> Function[DeleteMissing[#SourceSocket]]
};


With[{store = Language`NewExpressionStore["CSocketHandler"]},

    CSocketHandler[OptionsPattern[]] :=
    With[{handler = CSocketHandler[Null]},
        Map[store["put"[handler, #, OptionValue[#]]]&] @ Keys[Options[CSocketHandler]];

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
handleEvent[packet["Event"]][packet];


(handler_CSocketHandler)[packet_Association] /;
Not[KeyExistsQ[packet, "Event"]] && KeyExistsQ[packet, "DataByteArray"] && ByteArrayQ[packet["DataByteArray"]] :=
handleEvent["Received"][packet];


End[(*`Private`*)];


EndPackage[(*KirillBelov`CSockets`Handler`*)];