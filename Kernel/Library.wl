BeginPackage["KirillBelov`CSockets`Library`"];


socketListCreate::usage = "socketListCreate[iResult, length] -> (mint)socketsPtr";
socketListCreate = LibraryFunctionLoad[$lib, "socketListCreate", {Integer, Integer}, Integer];


socketListSet::usage = "socketListSet[socketList, socketsTensor] -> 0";
socketListSet = LibraryFunctionLoad[$lib, "socketListSet", {Integer, Integer}, Integer];


socketListRemove::usage = "socketListRemove[socketList] -> 0";
socketListRemove = LibraryFunctionLoad[$lib, "socketListRemove", {Integer}, Integer];


serverCreate::usage = "serverCreate[interrupt, listenSocket, clientsCapacity, bufferSize, timeout] -> serverPtr";
serverCreate = LibraryFunctionLoad[$lib, "serverCreate", {Integer, Integer, Integer, Integer, Integer}, Integer];


serverRemove::usage = "serverRemove[server] -> 0";
serverRemove = LibraryFunctionLoad[$lib, "serverRemove", {Integer}, Integer];


socketAddressInfoCreate::usage = "socketAddressInfoCreate[host] -> (mint)addressPtr";
socketAddressInfoCreate = LibraryFunctionLoad[$lib, "socketAddressInfoCreate", {UTF8String}, Integer];


socketAddressInfoRemove::usage = "socketAddressInfoRemove[addressPtr] -> 1";
socketAddressInfoRemove = LibraryFunctionLoad[$lib, "socketAddressInfoRemove", {Integer}, Integer];


socketAddressCreate::usage = "socketAddressCreate[] -> (mint)ptr";
socketAddressCreate = LibraryFunctionLoad[$lib, "socketAddressCreate", {}, Integer];


socketAddressRemove::usage = "socketAddressRemove[ptr] -> 0";
socketAddressRemove = LibraryFunctionLoad[$lib, "socketAddressRemove", {Integer}, Integer];


socketBufferCreate::usage = "socketBufferCreate[bufferSize] -> bufferPtr";
socketBufferCreate = LibraryFunctionLoad[$lib, "socketBufferCreate", {Integer}, Integer];


socketBufferRemove::usage = "socketBufferRemove[buffer] -> 0";
socketBufferRemove = LibraryFunctionLoad[$lib, "socketBufferRemove", {Integer}, Integer];


socketCreate::usage = "socketCreate[family, socktype, protocol] -> createdSocket";
socketCreate = LibraryFunctionLoad[$lib, "socketCreate", {Integer, Integer, Integer}, Integer];


socketClose::usage = "socketClose[] -> result";
socketClose = LibraryFunctionLoad[$lib, "socketClose", {}, Integer];


socketBind::usage = "socketBind[socketId, addressPtr] -> successState";
socketBind = LibraryFunctionLoad[$lib, "socketBind", {Integer, Integer}, Integer];


socketSetOpt::usage = "socketSetOpt[socketId, level, optname, optval] -> 0";
socketSetOpt = LibraryFunctionLoad[$lib, "socketSetOpt", {Integer, Integer, Integer, Integer}, Integer];


socketGetOpt::usage = "socketGetOpt[socketId, level, optname] -> optval";
socketGetOpt = LibraryFunctionLoad[$lib, "socketGetOpt", {Integer, Integer, Integer}, Integer];


socketBlockingMode::usage = "socketBlockingMode[socketId, nonBlocking] -> 0";
socketBlockingMode = LibraryFunctionLoad[$lib, "socketBlockingMode", {Integer, Integer}, Integer];


socketListen::usage = "socketListen[socketId, backlog] -> 0";
socketListen = LibraryFunctionLoad[$lib, "socketListen", {Integer, Integer}, Integer];


socketConnect::usage = "socketConnect[socketId, addressPtr, address] -> 0";
socketConnect = LibraryFunctionLoad[$lib, "socketConnect", {Integer, Integer, Integer}, Integer];


socketsCheck::usage = "socketsCheck[socketsTensor] -> validSocketsList";
socketsCheck = LibraryFunctionLoad[$lib, "socketsCheck", {Integer}, MTensor];


socketAccept::usage = "socketAccept[socketId] -> client";
socketAccept = LibraryFunctionLoad[$lib, "socketAccept", {Integer}, Integer];


socketRecv::usage = "socketRecv[client, buffer, bufferSize] -> byteArray";
socketRecv = LibraryFunctionLoad[$lib, "socketRecv", {Integer, Integer, Integer}, MNumericArray];


socketRecvFrom::usage = "socketRecvFrom[client, buffer, bufferSize, addressPtr] -> byteArray";
socketRecvFrom = LibraryFunctionLoad[$lib, "socketRecvFrom", {Integer, Integer, Integer, Integer}, MNumericArray];


socketSend::usage = "socketSend[socketId] -> result";
socketSend = LibraryFunctionLoad[$lib, "socketSend", {MNumericArray}, Integer];


socketSendString::usage = "socketSendString[socketId] -> result";
socketSendString = LibraryFunctionLoad[$lib, "socketSendString", {UTF8String}, Integer];


serverListen::usage = "serverListen[server] -> taskId";
serverListen = LibraryFunctionLoad[$lib, "serverListen", {Integer}, Integer];


socketsSelect::usage = "socketsSelect[socketIdsList, timeout] -> readySocketsTensor";
socketsSelect = LibraryFunctionLoad[$lib, "socketsSelect", {Integer, Integer}, MTensor];


createTaskSelect::usage = "createTaskSelect[socketListPtr] -> taskId";
createTaskSelect = LibraryFunctionLoad[$lib, "createTaskSelect", {Integer}, Integer];


createTaskSelectAcceptRecv::usage = "createTaskSelectAcceptRecv[serverPtr] -> taskId";
createTaskSelectAcceptRecv = LibraryFunctionLoad[$lib, "createTaskSelectAcceptRecv", {Integer}, Integer];


createTaskSelectRecvFrom::usage = "createTaskSelectRecvFrom[socketListPtr] -> taskId";
createTaskSelectRecvFrom = LibraryFunctionLoad[$lib, "createTaskSelectRecvFrom", {Integer}, Integer];

EndPackage[];