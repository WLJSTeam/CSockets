#ifndef ASYNC_H
#define ASYNC_H

#include "common.h"

typedef struct SocketSelectArgs_st
{
    WolframLibraryData libData;
    SOCKET *sockets;
    size_t length;
    mint timeout;
} *SocketSelectArgs;

void socketsSelectTask(mint taskId, void *taskArgs);

DLLEXPORT int socketsSelectAsync(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res);

typedef struct SocketSelectLoopArgs_st {
    WolframLibraryData libData;
    SocketList socketList;
    mint timeout;
} *SocketSelectLoopArgs;

void socketsSelectLoopTask(mint taskId, void *taskArgs);

DLLEXPORT int socketsSelectLoopAsync(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res);

typedef struct ServerLoopArgs_st
{
    WolframLibraryData libData;
    SocketList listenSockets;
    SocketList clientSockets;
    mint timeout;
    SOCKET interrupter;
} *ServerLoopArgs;

void serverLoopTask(mint taskId, void *taskArgs);

DLLEXPORT int createServerLoop(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res);

#endif