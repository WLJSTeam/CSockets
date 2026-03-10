#ifndef SLIST_H
#define SLIST_H

#include "common.h"

typedef struct SocketList_st {
    SOCKET *sockets;
    size_t capacity;
    size_t length;
} *SocketList;

DLLEXPORT int socketListCreate(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res);

DLLEXPORT int socketListRemove(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res);

DLLEXPORT int socketListAdd(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res);

DLLEXPORT int socketListGetAll(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res);

DLLEXPORT int socketListClear(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res);

int slistFdset(SocketList socketList, fd_set *set, int initmaxfd);

void slistAdd(SocketList slist, SOCKET socketId);

void slistClear(SocketList slist);

#endif