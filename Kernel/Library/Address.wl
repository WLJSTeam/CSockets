(* ::Package:: *)

BeginPackage["WLJS`CSockets`Library`Address`", {
    "WLJS`CSockets`Library`Common`",
    "CCompilerDriver`",
    "LibraryLink`"
}];


socketAddressInfoCreate::usage =
"socketAddressInfoCreate[host, port, fammily, socktype, protocol] returns address info pointer.
- host: \"localhost\"
- port: \"8000\"
- family: AF_UNSPEC == 0 | AF_INET == 2 | AF_INET6 == 23/10 | ..
- socktype: SOCK_STREAM == 1 | SOCK_DGRAM == 2 | SOCK_RAW == 3 | ..
- protocol: AUTO == 0 | IPPROTO_TCP == 6 | IPPROTO_UDP == 17 | IPPROTO_SCTP == 132 | IPPROTO_ICMP == 1 | ..";


socketAddressInfoRemove::usage =
"socketAddressInfoRemove[addressInfoPointer] free address info.";


Begin["`Private`"];


socketAddressInfoCreate =
LibraryFunctionLoad[$CSocketsLibrary, "socketAddressInfoCreate", {String, String, Integer, Integer, Integer}, Integer];


socketAddressInfoRemove =
LibraryFunctionLoad[$CSocketsLibrary, "socketAddressInfoRemove", {Integer}, "Void"];


End[];


EndPackage[];