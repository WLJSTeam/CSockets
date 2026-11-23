#ifndef ASYNC_H
#define ASYNC_H


#include "list.h"


typedef struct SocketListPollLoopArgs_st {
    WolframLibraryData libData;
    SocketList socketList;
    mint eventsMask;
    mint timeout;
} *SocketListPollLoopArgs;


#endif
