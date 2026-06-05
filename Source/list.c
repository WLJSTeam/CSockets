#include "list.h"


DLLEXPORT int socketListCreate(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res) {
    MTensor sockets = MArgument_getMTensor(Args[0]);
    mint* socketsData = libData->MTensor_getIntegerData(sockets);

    MTensor types = MArgument_getMTensor(Args[1]);
    mint* typesData = libData->MTensor_getIntegerData(types);

    size_t length = (size_t)MArgument_getInteger(Args[2]);

    SocketList socketList = socket_list_create(socketsData, typesData, length);
    mint socketListPtr = (mint)(uintptr_t)socketList;

    MArgument_setInteger(Res, socketListPtr);
    return LIBRARY_NO_ERROR;
}


DLLEXPORT int socketListAdd(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res) {
    SocketList socketList = (SocketList)MArgument_getInteger(Args[0]);
    SOCKET socketId = (SOCKET)MArgument_getInteger(Args[1]);
    SOCKET_TYPE socketType = (SOCKET_TYPE)MArgument_getInteger(Args[2]);
    socket_list_add(socketList, socketId, socketType);
    return LIBRARY_NO_ERROR;
}


DLLEXPORT int socketListGetAll(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res) {
    SocketList socketList = (SocketList)MArgument_getInteger(Args[0]);
    POLL_FD *pollfds = socketList->pollfds;
    const mint length = socketList->length;
    const mint dimensions[2] = {length, 2};

    MTensor socketsTensor;
    libData->MTensor_new(MType_Integer, 2, &dimensions, &socketsTensor);
    mint *socketsData = libData->MTensor_getIntegerData(socketsTensor);

    for (size_t i = 0; i < length; i++) {
        socketsData[i] = (mint)pollfds[i].fd;
    }

    MArgument_setMTensor(Res, socketsTensor);
    return LIBRARY_NO_ERROR;
}


DLLEXPORT int socketListPrune(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res) {
    SocketList socketList = (SocketList)MArgument_getInteger(Args[0]);
    socket_list_prune(socketList);
    return LIBRARY_NO_ERROR;
}


DLLEXPORT int socketListDelete(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res) {
    SocketList socketList = (SocketList)MArgument_getInteger(Args[0]);
    socket_list_free(socketList);
    return LIBRARY_NO_ERROR;
}


SocketList socket_list_create(mint *sockets, mint *types, size_t length) {
    size_t capacity = 1;
    while (capacity < length)
    {
        capacity *= 2;
    }

    POLL_FD *pollfds = malloc(sizeof(POLL_FD) * capacity);
    struct addrinfo **addrinfos = malloc(sizeof(struct addrinfo*) * capacity);
    SOCKET_TYPE *sockettypes = malloc(sizeof(SOCKET_TYPE) * capacity);

    for (size_t i = 0; i < length; i++) {
        pollfds[i].fd = (SOCKET)sockets[i];
        sockettypes[i] = (SOCKET_TYPE)types[i];
        addrinfos[i] = NULL;
    }

    SocketList socketList = malloc(sizeof(struct SocketList_st));
    socketList->pollfds = pollfds;
    socketList->addrinfos = addrinfos;
    socketList->sockettypes = sockettypes;
    socketList->length = length;
    socketList->capacity = capacity;

    return socketList;
}


void socket_list_add(SocketList socketList, SOCKET socketId, SOCKET_TYPE socketType) {
    socketList->pollfds[socketList->length].fd = socketId;
    socketList->addrinfos[socketList->length] = NULL;
    socketList->sockettypes[socketList->length] = socketType;
    socketList->length++;

    if (socketList->length == socketList->capacity) {
        socketList->capacity *= 2;
        socketList->pollfds = realloc(socketList->pollfds, sizeof(POLL_FD) * socketList->capacity);
        socketList->addrinfos = realloc(socketList->addrinfos, sizeof(struct addrinfo*) * socketList->capacity);
        socketList->sockettypes = realloc(socketList->sockettypes, sizeof(SOCKET_TYPE) * socketList->capacity);
    }
}


void socket_list_prune(SocketList socketList) {
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


void socket_list_free(SocketList socketList) {
    free(socketList->pollfds);
    free(socketList->addrinfos);
    free(socketList->sockettypes);
    free(socketList);
}