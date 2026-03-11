#ifndef LIST_H
#define LIST_H

#include "common.h"

typedef struct SocketList_st {
    SOCKET *sockets;
    mint capacity;
    mint length;
} *SocketList;

typedef struct AddressInfoList_st {
    struct addrinfo **adrrinfos;
    mint length;
    mint capacity;
} *AddressInfoList;

DLLEXPORT int socketListCreate(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res);

DLLEXPORT int socketListRemove(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res);

DLLEXPORT int socketListAdd(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res);

DLLEXPORT int socketListGetAll(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res);

DLLEXPORT int socketListClear(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res);

DLLEXPORT int socketAddressInfoListCreate(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res);

DLLEXPORT int socketAddressInfoListRemove(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res);

void slistAdd(SocketList slist, SOCKET socketId);

void slistClear(SocketList slist);

#endif