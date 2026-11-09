#include "list.h"


DLLEXPORT int socketListCreate(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    MTensor sockets = MArgument_getMTensor(Args[0]);
    mint* socketsData = libData->MTensor_getIntegerData(sockets);

    MTensor types = MArgument_getMTensor(Args[1]);
    mint* typesData = libData->MTensor_getIntegerData(types);

    size_t length = (size_t)MArgument_getInteger(Args[2]);

    SocketList socketList = socket_list_create(socketsData, typesData, length);
    if (!socketList) {
        return LIBRARY_FUNCTION_ERROR;
    }

    mint socketListPtr = (mint)(uintptr_t)socketList;
    MArgument_setInteger(Res, socketListPtr);
    return LIBRARY_NO_ERROR;
}


DLLEXPORT int socketListAdd(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    SocketList socketList = (SocketList)MArgument_getInteger(Args[0]);
    SOCKET socketId = (SOCKET)MArgument_getInteger(Args[1]);
    SOCKET_TYPE socketType = (SOCKET_TYPE)MArgument_getInteger(Args[2]);

    if (!socket_list_add(socketList, socketId, socketType)) {
        return LIBRARY_FUNCTION_ERROR;
    }

    return LIBRARY_NO_ERROR;
}


DLLEXPORT int socketListGetAll(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    SocketList socketList = (SocketList)MArgument_getInteger(Args[0]);
    POLL_FD *pollfds = socketList->pollfds;
    SOCKET_TYPE *types = socketList->sockettypes;
    const mint length = socketList->length;
    const mint dimensions[2] = {length, 2};

    MTensor socketsTensor;
    libData->MTensor_new(MType_Integer, 2, dimensions, &socketsTensor);
    mint *socketsData = libData->MTensor_getIntegerData(socketsTensor);

    for (size_t i = 0; i < length; i++) {
        socketsData[2 * i] = (mint)pollfds[i].fd;
        socketsData[2 * i + 1] = (mint)types[i];
    }

    MArgument_setMTensor(Res, socketsTensor);
    return LIBRARY_NO_ERROR;
}


DLLEXPORT int socketListPrune(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    SocketList socketList = (SocketList)MArgument_getInteger(Args[0]);
    socket_list_prune(socketList);
    return LIBRARY_NO_ERROR;
}


DLLEXPORT int socketListDelete(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    SocketList socketList = (SocketList)MArgument_getInteger(Args[0]);
    socket_list_free(socketList);
    return LIBRARY_NO_ERROR;
}


SocketList socket_list_create(mint *sockets, mint *types, size_t length)
{
    size_t capacity = 1;
    while (capacity < length)
    {
        capacity *= 2;
    }

    POLL_FD *pollfds = malloc(sizeof(POLL_FD) * capacity);
    if (!pollfds) {
        return NULL;
    }

    struct addrinfo **addrinfos = malloc(sizeof(struct addrinfo*) * capacity);
    if (!addrinfos) {
        free(pollfds);
        return NULL;
    }

    SOCKET_TYPE *sockettypes = malloc(sizeof(SOCKET_TYPE) * capacity);
    if (!sockettypes) {
        free(pollfds);
        free(addrinfos);
        return NULL;
    }

    for (size_t i = 0; i < length; i++) {
        pollfds[i].fd = (SOCKET)sockets[i];
        sockettypes[i] = (SOCKET_TYPE)types[i];
        addrinfos[i] = NULL;
    }

    SocketList socketList = malloc(sizeof(struct SocketList_st));
    if (!socketList) {
        free(pollfds);
        free(addrinfos);
        free(sockettypes);
        return NULL;
    }

    socketList->pollfds = pollfds;
    socketList->addrinfos = addrinfos;
    socketList->sockettypes = sockettypes;
    socketList->length = length;
    socketList->capacity = capacity;

    return socketList;
}


bool socket_list_add(SocketList socketList, SOCKET socketId, SOCKET_TYPE socketType)
{
    if (!socketList) {
        return false;
    }

    if (socketList->length == socketList->capacity) {
        size_t newCapacity = socketList->capacity * 2;

        POLL_FD *newPollfds = malloc(sizeof(POLL_FD) * newCapacity);
        if (!newPollfds) {
            return false;
        }

        struct addrinfo **newAddrinfos = malloc(sizeof(struct addrinfo*) * newCapacity);
        if (!newAddrinfos) {
            free(newPollfds);
            return false;
        }

        SOCKET_TYPE *newSockettypes = malloc(sizeof(SOCKET_TYPE) * newCapacity);
        if (!newSockettypes) {
            free(newPollfds);
            free(newAddrinfos);
            return false;
        }

        memcpy(newPollfds, socketList->pollfds, sizeof(POLL_FD) * socketList->length);
        memcpy(newAddrinfos, socketList->addrinfos, sizeof(struct addrinfo*) * socketList->length);
        memcpy(newSockettypes, socketList->sockettypes, sizeof(SOCKET_TYPE) * socketList->length);

        free(socketList->pollfds);
        free(socketList->addrinfos);
        free(socketList->sockettypes);

        socketList->pollfds = newPollfds;
        socketList->addrinfos = newAddrinfos;
        socketList->sockettypes = newSockettypes;
        socketList->capacity = newCapacity;
    }

    socketList->pollfds[socketList->length].fd = socketId;
    socketList->addrinfos[socketList->length] = NULL;
    socketList->sockettypes[socketList->length] = socketType;
    socketList->length++;
    return true;
}


void socket_list_prune(SocketList socketList)
{
    mint j = 0;
    for (mint i = 0; i < socketList->length; i++) {
        if (socketList->pollfds[i].fd != INVALID_SOCKET) {
            if (i != j) {
                socketList->pollfds[j] = socketList->pollfds[i];
                socketList->addrinfos[j] = socketList->addrinfos[i];
                socketList->sockettypes[j] = socketList->sockettypes[i];
            }
            j++;
        }
    }
    socketList->length = j;
}


void socket_list_free(SocketList socketList)
{
    free(socketList->pollfds);
    free(socketList->addrinfos);
    free(socketList->sockettypes);
    free(socketList);
}