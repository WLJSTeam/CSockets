(* ::Package:: *)

BeginPackage["KirillBelov`CSockets`Library`", {
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
"socketAddressInfoRemove[addressInfoPointer] returns success state == 1.";


socketAddressGet::usage =
"socketAddressGet[addressInfoPointer] returns address pointer.";


socketBufferCreate::usage =
"socketBufferCreate[bufferSize] returns buffer pointer.";


socketBufferRemove::usage =
"socketBufferRemove[bufferPointer] returns success state == 1.";


socketCreate::usage = "socketCreate[family, socktype, protocol] returns unbound socket id.
- family: AF_UNSPEC == 0 | AF_INET == 2 | AF_INET6 == 23/10 | ..
- socktype: SOCK_STREAM == 1 | SOCK_DGRAM == 2 | SOCK_RAW == 3 | ..
- protocol: AUTO == 0 | IPPROTO_TCP == 6 | IPPROTO_UDP == 17 | IPPROTO_SCTP == 132 | IPPROTO_ICMP == 1 | ..";


socketClose::usage =
"socketClose[socketId] returns success state == 1.";


socketBind::usage =
"socketBind[socketId, addressPointer] returns success state == 1.";


socketSetOpt::usage =
"socketSetOpt[socketId, level, optname, optval] returns success state == 1.
- level:
- optname:
- optval: ";


socketGetOpt::usage =
"socketGetOpt[socketId, level, optname] returns optval.
    level:
    optname: ";


socketSetBlockingMode::usage =
"socketSetBlockingMode[socketId, blockingMode] returns success state == 1.
- blockingMode: blocking == 0 | non-blocking == 1";


socketListen::usage =
"socketListen[socketId, backlog] returns success state == 1.
- socketId: only created with SOCK_STEAM type
- backlog: client store size for acception";


socketConnect::usage =
"socketConnect[socketId, addressPointer, wait] returns connection socket id.";


socketAccept::usage =
"socketAccept[socketId] returns client socket id.
- socketId: only listening socket";


socketRecv::usage =
"socketRecv[socketId, bufferPointer, bufferSize] returns byte array.
- socketId: except listening sockets";


socketRecvFrom::usage =
"socketRecvFrom[socketId, bufferPointer, bufferSize, addressPointer] returns byte array.
- addressPointer: contains remote client address when data will receive.";


socketSend::usage =
"socketSend[socketId, byteArray, byteArrayLength] returns size of the sent message == byteArrayLength.";


socketSendString::usage =
"socketSendString[socketId, string, stringLength] returns size of the sent message == stringLength.";


socketSendTo::usage =
"socketSendString[socketId, addressInfo, byteArray, byteArrayLength] returns size of the sent message == byteArrayLength.";


socketsCheck::usage =
"socketsCheck[sockets, length] returns only valid sockets.
- sockets: built-in List with socket ids.";


socketsSelect::usage =
"socketsSelect[sockets, length, timeout] returns list of ready socket ids.
- sockets: built-in List with socket ids.";


socketsSelectAsync::usage =
"socketsSelectAsync[sockets, length, timeout] creates a thread where waits for sockets to be ready.
- sockets: built-in List with socket ids.";


Begin["`Private`"];


$directory =
DirectoryName[$InputFileName, 2];


$libraryLinkVersion =
LibraryVersionInformation[FindLibrary["demo"]]["WolframLibraryVersion"];


$libFile = FileNameJoin[{
    $directory,
    "LibraryResources",
    $SystemID <> "-v" <> ToString[$libraryLinkVersion],
    "csockets." <> Internal`DynamicLibraryExtension[]
}];


If[!FileExistsQ[$libFile],
    Get[FileNameJoin[{$directory, "Build.wls"}]]
];


socketAddressInfoCreate =
LibraryFunctionLoad[$libFile, "socketAddressInfoCreate", {String, String, Integer, Integer, Integer}, Integer];


socketAddressInfoRemove =
LibraryFunctionLoad[$libFile, "socketAddressInfoRemove", {Integer}, Integer];


socketAddressGet =
LibraryFunctionLoad[$libFile, "socketAddressGet", {Integer}, Integer];


socketBufferCreate =
LibraryFunctionLoad[$libFile, "socketBufferCreate", {Integer}, Integer];


socketBufferRemove =
LibraryFunctionLoad[$libFile, "socketBufferRemove", {Integer}, Integer];


socketCreate =
LibraryFunctionLoad[$libFile, "socketCreate", {Integer, Integer, Integer}, Integer];


socketClose =
LibraryFunctionLoad[$libFile, "socketClose", {Integer}, Integer];


socketBind =
LibraryFunctionLoad[$libFile, "socketBind", {Integer, Integer}, Integer];


socketSetOpt =
LibraryFunctionLoad[$libFile, "socketSetOpt", {Integer, Integer, Integer, Integer}, Integer];


socketGetOpt =
LibraryFunctionLoad[$libFile, "socketGetOpt", {Integer, Integer, Integer}, Integer];


socketSetBlockingMode =
LibraryFunctionLoad[$libFile, "socketSetBlockingMode", {Integer, Integer}, Integer];


socketListen =
LibraryFunctionLoad[$libFile, "socketListen", {Integer, Integer}, Integer];


socketConnect =
LibraryFunctionLoad[$libFile, "socketConnect", {Integer, Integer, Integer}, Integer];


socketAccept =
LibraryFunctionLoad[$libFile, "socketAccept", {Integer}, Integer];


socketRecv =
LibraryFunctionLoad[$libFile, "socketRecv", {Integer, Integer, Integer}, "ByteArray"];


socketRecvFrom =
LibraryFunctionLoad[$libFile, "socketRecvFrom", {Integer, Integer, Integer, Integer}, "ByteArray"];


socketSend =
LibraryFunctionLoad[$libFile, "socketSend", {Integer, "ByteArray", Integer}, Integer];


socketSendString =
LibraryFunctionLoad[$libFile, "socketSendString", {Integer, String, Integer}, Integer];


socketsCheck =
LibraryFunctionLoad[$libFile, "socketsCheck", {Integer}, {Integer, 1}];


socketsSelect =
LibraryFunctionLoad[$libFile, "socketsSelect", {{Integer, 1}, Integer, Integer}, {Integer, 1}];


createSocketsSelectTask =
LibraryFunctionLoad[$libFile, "socketsSelectAsync", {{Integer, 1}, Integer, Integer}, Integer];


End[];


EndPackage[];