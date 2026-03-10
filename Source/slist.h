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

DLLEXPORT int socketListAddt(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res);

DLLEXPORT int socketListClear(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res);

void slistAdd(SocketList slist, SOCKET socketId);

void slistClear(SocketList slist);

#endif