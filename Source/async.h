#ifndef ASYNC_H
#define ASYNC_H


#include "common.h"
#include "list.h"


typedef struct SocketsSelectArgs_st
{
    WolframLibraryData libData;
    SOCKET *sockets;
    size_t length;
    mint timeout;
} *SocketsSelectArgs;


typedef struct ServerLoopArgs_st
{
    WolframLibraryData libData;
    SocketList socketList;
    mint bufferSize;
    mint timeout;
    mint eventsMask;
} *ServerLoopArgs;


#endif