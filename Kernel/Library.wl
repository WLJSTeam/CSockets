(* ::Package:: *)


BeginPackage["WLJS`CSockets`Library`", {"LibraryLink`", "CCompilerDriver`"}];


$CSocketsLibrary =
FileNameJoin[{DirectoryName[$InputFileName, 2], "LibraryResources", $SystemID <> "-v" <> ToString[LibraryVersionInformation[FindLibrary["demo"]]["WolframLibraryVersion"]], "csockets." <> Internal`DynamicLibraryExtension[]}];


socketAddressInfoCreate::usage =
"socketAddressInfoCreate[host, port, aiFamily, aiSocktype, aiProtocol, localIP] -> addressPtr.";


socketAddressInfoCreate =
LibraryFunctionLoad[$CSocketsLibrary, "socketAddressInfoCreate", {String, String, Integer, Integer, Integer, String}, Integer];


socketAddressInfoRemove::usage =
"socketAddressInfoRemove[addressPtr].";


socketAddressInfoRemove =
LibraryFunctionLoad[$CSocketsLibrary, "socketAddressInfoRemove", {Integer}, "Void"];


socketsSelectAsync::usage =
"socketsSelectAsync[socketIds, length, timeout] -> taskId.";


socketsSelectAsync =
LibraryFunctionLoad[$CSocketsLibrary, "socketsSelectAsync", {{Integer, 1}, Integer, Integer}, Integer];


createSocketsPollLoop::usage =
"createSocketsPollLoop[socketList, bufferSize, timeout, eventsMask] -> taskId.";


createSocketsPollLoop =
LibraryFunctionLoad[$CSocketsLibrary, "createSocketsPollLoop", {Integer, Integer, Integer, Integer}, Integer];


socketBufferCreate::usage =
"socketBufferCreate[bufferSize] -> bufferPtr.";


socketBufferCreate =
LibraryFunctionLoad[$CSocketsLibrary, "socketBufferCreate", {Integer}, Integer];


socketBufferRemove::usage =
"socketBufferRemove[buffer].";


socketBufferRemove =
LibraryFunctionLoad[$CSocketsLibrary, "socketBufferRemove", {Integer}, "Void"];


socketListCreate::usage =
"socketListCreate[sockets, types, length] -> socketListPtr.";


socketListCreate =
LibraryFunctionLoad[$CSocketsLibrary, "socketListCreate", {{Integer, 1}, {Integer, 1}, Integer}, Integer];


socketListAdd::usage =
"socketListAdd[socketList, socketId, socketType].";


socketListAdd =
LibraryFunctionLoad[$CSocketsLibrary, "socketListAdd", {Integer, Integer, Integer}, "Void"];


socketListGetAll::usage =
"socketListGetAll[socketList] -> socketsTensor.";


socketListGetAll =
LibraryFunctionLoad[$CSocketsLibrary, "socketListGetAll", {Integer}, {Integer, 2}];


socketListPrune::usage =
"socketListPrune[socketList].";


socketListPrune =
LibraryFunctionLoad[$CSocketsLibrary, "socketListPrune", {Integer}, "Void"];


socketListDelete::usage =
"socketListDelete[socketList].";


socketListDelete =
LibraryFunctionLoad[$CSocketsLibrary, "socketListDelete", {Integer}, "Void"];


socketCreate::usage =
"socketCreate[family, socktype, protocol] -> createdSocket.";


socketCreate =
LibraryFunctionLoad[$CSocketsLibrary, "socketCreate", {Integer, Integer, Integer}, Integer];


socketClose::usage =
"socketClose[socketId].";


socketClose =
LibraryFunctionLoad[$CSocketsLibrary, "socketClose", {Integer}, "Void"];


socketBind::usage =
"socketBind[socketId, addressInfoPtr].";


socketBind =
LibraryFunctionLoad[$CSocketsLibrary, "socketBind", {Integer, Integer}, "Void"];


socketSetOpt::usage =
"socketSetOpt[socketId, level, optname, optval].";


socketSetOpt =
LibraryFunctionLoad[$CSocketsLibrary, "socketSetOpt", {Integer, Integer, Integer, Integer}, "Void"];


socketGetOpt::usage =
"socketGetOpt[socketId, level, optname] -> optval.";


socketGetOpt =
LibraryFunctionLoad[$CSocketsLibrary, "socketGetOpt", {Integer, Integer, Integer}, Integer];


socketSetBlockingMode::usage =
"socketSetBlockingMode[socketId].";


socketSetBlockingMode =
LibraryFunctionLoad[$CSocketsLibrary, "socketSetBlockingMode", {Integer}, "Void"];


socketSetNonBlockingMode::usage =
"socketSetNonBlockingMode[socketId].";


socketSetNonBlockingMode =
LibraryFunctionLoad[$CSocketsLibrary, "socketSetNonBlockingMode", {Integer}, "Void"];


socketListen::usage =
"socketListen[socketId, backlog].";


socketListen =
LibraryFunctionLoad[$CSocketsLibrary, "socketListen", {Integer, Integer}, "Void"];


socketConnect::usage =
"socketConnect[socketId, addressInfoPtr].";


socketConnect =
LibraryFunctionLoad[$CSocketsLibrary, "socketConnect", {Integer, Integer}, "Void"];


socketAccept::usage =
"socketAccept[socketId] -> acceptedSocketId.";


socketAccept =
LibraryFunctionLoad[$CSocketsLibrary, "socketAccept", {Integer}, Integer];


socketRecv::usage =
"socketRecv[socketId, buffer, bufferSize] -> byteArray.";


socketRecv =
LibraryFunctionLoad[$CSocketsLibrary, "socketRecv", {Integer, Integer, Integer}, "ByteArray"];


socketRecvFrom::usage =
"socketRecvFrom[client, addressInfoPtr, buffer, bufferSize] -> byteArray.";


socketRecvFrom =
LibraryFunctionLoad[$CSocketsLibrary, "socketRecvFrom", {Integer, Integer, Integer, Integer}, "ByteArray"];


socketSend::usage =
"socketSend[socketId, byteArray, length] -> sentLength.";


socketSend =
LibraryFunctionLoad[$CSocketsLibrary, "socketSend", {Integer, {"ByteArray", "Shared"}, Integer}, Integer];


socketSendString::usage =
"socketSendString[socketId, text, length] -> sentLength.";


socketSendString =
LibraryFunctionLoad[$CSocketsLibrary, "socketSendString", {Integer, String, Integer}, Integer];


socketSendTo::usage =
"socketSendTo[socketId, addressInfo, byteArray, length] -> sentLength.";


socketSendTo =
LibraryFunctionLoad[$CSocketsLibrary, "socketSendTo", {Integer, Integer, {"ByteArray", "Shared"}, Integer}, Integer];


socketSendStringTo::usage =
"socketSendStringTo[socketId, addressInfo, text, length] -> sentLength.";


socketSendStringTo =
LibraryFunctionLoad[$CSocketsLibrary, "socketSendStringTo", {Integer, Integer, String, Integer}, Integer];


socketsCheck::usage =
"socketsCheck[socketsTensor, length] -> validSocketsList.";


socketsCheck =
LibraryFunctionLoad[$CSocketsLibrary, "socketsCheck", {{Integer, 1}, Integer}, {Integer, 1}];


socketsSelect::usage =
"socketsSelect[sockets, length, timeout, mode] -> readySockets.";


socketsSelect =
LibraryFunctionLoad[$CSocketsLibrary, "socketsSelect", {{Integer, 1}, Integer, Integer, Integer}, {Integer, 1}];


socketsPoll::usage =
"socketsPoll[socketsTensor, length, timeoutUs, eventsMask] -> resultTensor.";


socketsPoll =
LibraryFunctionLoad[$CSocketsLibrary, "socketsPoll", {{Integer, 1}, Integer, Integer, Integer}, {Integer, 1}];


EndPackage[];