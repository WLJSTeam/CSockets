(* ::Package:: *)

BeginPackage["WLJS`CSockets`", {
    "WLJS`CSockets`Library`"
}];


CSocketOpen::usage =
"CSocketOpen[port]";


CSocketConnect::usage =
"CSocketOpen[host, port]";


CSocketObject::usage =
"CSocketObject[]";


Begin["`Private`"];


CSocketOpen[host_String: "localhost", port_Integer, protocol: "TCP" | "UDP": "TCP"] :=
With[{
    addressInfo = socketAddressInfoCreate[host, ToString[port], 2, protocol /. {"TCP" -> 1, "UDP" -> 2}, 0],
    socketId = socketCreate[2, protocol /. {"TCP" -> 1, "UDP" -> 2}, 0]
},
    socketBind[socketId, addressInfo];
    If[protocol == "TCP", socketListen[socketId, 4096]];
    CSocketObject[socketId]
];


End[];


EndPackage[];