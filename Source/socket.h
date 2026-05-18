#ifndef SOCKET_H
#define SOCKET_H


#include "common.h"


/*socketCreate[family, socktype, protocol] -> socketId*/
DLLEXPORT int socketCreate(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res);


/*socketClose[socketId]*/
DLLEXPORT int socketClose(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res);


/*socketBind[socketId, addressInfoPtr] -> successStatus*/
DLLEXPORT int socketBind(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res);


/*socketSetOpt[socketId, level, optname, optval] -> successStatus*/
DLLEXPORT int socketSetOpt(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res);


/*socketGetOpt[socketId, level, optname] -> optval*/
DLLEXPORT int socketGetOpt(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res);


/*socketSetBlockingMode[socketId]*/
DLLEXPORT int socketSetBlockingMode(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res);


/*socketSetNonBlockingMode[socketId]*/
DLLEXPORT int socketSetNonBlockingMode(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res);


/*socketCreate[family, socktype, protocol]*/
DLLEXPORT int socketListen(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res);


/*socketConnect[socketId, addressInfo]*/
DLLEXPORT int socketConnect(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res);


/*socketAccept[socketId] -> clientId*/
DLLEXPORT int socketAccept(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res);


/*socketRecv[socketId, bufferPtr, bufferSize] -> byteArray*/
DLLEXPORT int socketRecv(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res);


/*socketRecvFrom[socketId, addressInfoPtr, bufferPtr, bufferSize] -> byteArray (only UDP)*/
DLLEXPORT int socketRecvFrom(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res);


/*socketSend[socketId, byteArray, length] -> sentLength*/
DLLEXPORT int socketSend(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res);


/*socketSendString[socketId, text, length] -> sentLength*/
DLLEXPORT int socketSendString(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res);


/*socketSendTo[socketId, addressInfoPtr, byteArray, length] -> sentLength (only UDP)*/
DLLEXPORT int socketSendTo(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res);


/*socketSendStringTo[socketId, addressInfoPtr, text, length] -> sentLength*/
DLLEXPORT int socketSendStringTo(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res);


/*socketsSelect[sockets, length, timeout, mode] -> readySockets*/
DLLEXPORT int socketsCheck(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res);


/*socketsSelect[sockets, length, timeout, mode] -> readySockets*/
DLLEXPORT int socketsSelect(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res);


/*socketsPoll[sockets, length, timeout_us, eventsMask] -> {{socket, events}, ...} */
DLLEXPORT int socketsPoll(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res);


#endif