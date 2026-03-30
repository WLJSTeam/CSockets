(* ::Package:: *)

BeginPackage["WLJS`CSockets`Library`Socket`", {
    "WLJS`Csockets`Library`Common`",
    "CCompilerDriver`",
    "LibraryLink`"
}];


socketCreate::usage = "socketCreate[family, socktype, protocol] returns unbound socket id.
- family: AF_UNSPEC == 0 | AF_INET == 2 | AF_INET6 == 23/10 | ..
- socktype: SOCK_STREAM == 1 | SOCK_DGRAM == 2 | SOCK_RAW == 3 | ..
- protocol: AUTO == 0 | IPPROTO_TCP == 6 | IPPROTO_UDP == 17 | IPPROTO_SCTP == 132 | IPPROTO_ICMP == 1 | ..";


socketClose::usage =
"socketClose[socketId] returns success state == 1.";


socketBind::usage =
"socketBind[socketId, addressInfo] returns success state == 1.";


socketSetOpt::usage =
"socketSetOpt[socketId, level, optname, optval] returns success state == 1.
- level:
- optname:
- optval: ";


socketGetOpt::usage =
"socketGetOpt[socketId, level, optname] returns optval.
- level:
- optname: ";


socketSetBlockingMode::usage =
"socketSetBlockingMode[socketId, blockingMode] returns success state.
- blockingMode: blocking == True | non-blocking == False";


socketListen::usage =
"socketListen[socketId, backlog] returns success state.
- socketId: only created with SOCK_STEAM type
- backlog: client store size for acception";


socketConnect::usage =
"socketConnect[socketId, addressInfo] returns success state.";


socketAccept::usage =
"socketAccept[socketId] returns client socket id.
- socketId: only listening socket";


socketRecv::usage =
"socketRecv[socketId, buffer, bufferSize] returns byte array.
- socketId: except listening sockets";


socketRecvFrom::usage =
"socketRecvFrom[socketId, addressInfo, buffer, bufferSize] returns byte array.
- addressInfo: contains remote client address when data will receive.";


socketSend::usage =
"socketSend[socketId, byteArray, byteArrayLength] returns size of the sent message == byteArrayLength.";


socketSendString::usage =
"socketSendString[socketId, string, stringLength] returns size of the sent message == stringLength.";


socketSendTo::usage =
"socketSendTo[socketId, addressInfo, byteArray, byteArrayLength] returns size of the sent message == byteArrayLength.";


socketsCheck::usage =
"socketsCheck[sockets, length] returns only valid sockets.
- sockets: built-in List with socket ids.";


socketsSelect::usage =
"socketsSelect[sockets, length, timeout] returns list of ready socket ids.
- sockets: built-in List with socket ids.";


socketsSelectForWrite::usage =
"socketsSelectForWrite[sockets, length, timeout] returns list of ready socket ids.
- sockets: built-in List with socket ids.";


Begin["`Private`"];


socketCreate =
LibraryFunctionLoad[$CSocketsLibrary, "socketCreate", {Integer, Integer, Integer}, Integer];


socketClose =
LibraryFunctionLoad[$CSocketsLibrary, "socketClose", {Integer}, "Boolean"];


socketBind =
LibraryFunctionLoad[$CSocketsLibrary, "socketBind", {Integer, Integer}, "Boolean"];


socketSetOpt =
LibraryFunctionLoad[$CSocketsLibrary, "socketSetOpt", {Integer, Integer, Integer, Integer}, "Boolean"];


socketGetOpt =
LibraryFunctionLoad[$CSocketsLibrary, "socketGetOpt", {Integer, Integer, Integer}, Integer];


socketSetBlockingMode =
LibraryFunctionLoad[$CSocketsLibrary, "socketSetBlockingMode", {Integer, Integer}, "Boolean"];


socketListen =
LibraryFunctionLoad[$CSocketsLibrary, "socketListen", {Integer, Integer}, "Void"];


socketConnect =
LibraryFunctionLoad[$CSocketsLibrary, "socketConnect", {Integer, Integer}, "Void"];


socketAccept =
LibraryFunctionLoad[$CSocketsLibrary, "socketAccept", {Integer}, Integer];


socketRecv =
LibraryFunctionLoad[$CSocketsLibrary, "socketRecv", {Integer, Integer, Integer}, "ByteArray"];


socketRecvFrom =
LibraryFunctionLoad[$CSocketsLibrary, "socketRecvFrom", {Integer, Integer, Integer, Integer}, "ByteArray"];


socketSend =
LibraryFunctionLoad[$CSocketsLibrary, "socketSend", {Integer, "ByteArray", Integer}, Integer];


socketSendString =
LibraryFunctionLoad[$CSocketsLibrary, "socketSendString", {Integer, String, Integer}, Integer];


socketSendTo =
LibraryFunctionLoad[$CSocketsLibrary, "socketSendTo", {Integer, Integer, "ByteArray", Integer}, Integer];


socketsCheck =
LibraryFunctionLoad[$CSocketsLibrary, "socketsCheck", {Integer}, {Integer, 1}];


socketsSelect =
LibraryFunctionLoad[$CSocketsLibrary, "socketsSelect", {{Integer, 1}, Integer, Integer, Integer}, {Integer, 1}];


socketsPoll =
LibraryFunctionLoad[$CSocketsLibrary, "socketsPoll", {{Integer, 1}, Integer, Integer, Integer}, {Integer, 1}];


End[];


EndPackage[];