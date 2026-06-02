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


typedef struct ServerLoopArgs_st {
    WolframLibraryData libData;
    SocketList socketList;
    mint bufferSize;
    mint timeout;
    mint eventsMask;
} *ServerLoopArgs;


void socketsPollLoop(mint taskId, void *taskArgs);


#endif