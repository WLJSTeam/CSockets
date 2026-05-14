#ifndef ASYNC_H
#define ASYNC_H


#include "common.h"
#include "list.h"


typedef struct SocketsSelectArgs_st {
    WolframLibraryData libData;
    SOCKET *sockets;
    size_t length;
    mint timeout;
} *SocketsSelectArgs;


void socketsSelectTask(mint taskId, void *taskArgs);


DLLEXPORT int socketsSelectAsync(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res);


typedef struct SocketsSelectLoopArgs_st {
    WolframLibraryData libData;
    SocketList socketList;
    mint timeout;
} *SocketsSelectLoopArgs;


void socketsSelectLoop(mint taskId, void *taskArgs);


DLLEXPORT int createSocketsSelectLoop(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res);


typedef struct ServerLoopArgs_st {
    WolframLibraryData libData;
    SocketList acceptSockets;
    SocketList recvSockets;
    SocketList recvFromSockets;
    AddressInfoList recvFromAddrInfos;
    BYTE *buffer;
    mint bufferSize;
    mint timeout;
    SOCKET interrupter;
} *ServerLoopArgs;


void serverLoop(mint taskId, void *taskArgs);


DLLEXPORT int createServerLoop(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res);


#endif