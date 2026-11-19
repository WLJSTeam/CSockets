#ifndef ASYNC_H
#define ASYNC_H


#include "list.h"


typedef struct SocketsPollArgs_st {
    WolframLibraryData libData;
    SOCKET *sockets;
    mint length;
    mint timeout;
    mint eventsMask;
    SocketList list;
} *SocketsPollArgs;


#endif
