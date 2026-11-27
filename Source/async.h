#ifndef ASYNC_H
#define ASYNC_H


#include "common.h"


typedef struct SocketPollLoopArgs_st {
    WolframLibraryData libData;
    socket_list *socketList;
    mint eventsMask;
    mint timeout;
    int bufferSize;
    BYTE *buffer;
} *SocketPollLoopArgs;


#endif
