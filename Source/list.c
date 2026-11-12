#include "list.h"


DLLEXPORT int socketListCreate(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    (void)Args;
    if (Argc != 0) {
        libData->Message("socketListCreate: invalid argument count");
        return LIBRARY_FUNCTION_ERROR;
    }

    size_t capacity = 1;

    SocketList socketList = malloc(sizeof(struct SocketList_st));
    if (!socketList) {
        libData->Message("socketListCreate: allocation failed for SocketList");
        return LIBRARY_FUNCTION_ERROR;
    }

    socketList->sockets = calloc(capacity, sizeof(SocketObject));
    if (!socketList->sockets) {
        free(socketList);
        libData->Message("socketListCreate: allocation failed for sockets array");
        return LIBRARY_FUNCTION_ERROR;
    }

    socketList->pollfds = calloc(capacity, sizeof(POLL_FD));
    if (!socketList->pollfds) {
        free(socketList->sockets);
        free(socketList);
        libData->Message("socketListCreate: allocation failed for pollfds array");
        return LIBRARY_FUNCTION_ERROR;
    }

    socketList->length = 0;
    socketList->capacity = capacity;

    mint socketListPtr = (mint)(uintptr_t)socketList;
    MArgument_setInteger(Res, socketListPtr);
    return LIBRARY_NO_ERROR;
}


DLLEXPORT int socketListAdd(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    (void)Res;
    if (Argc != 2) {
        libData->Message("socketListAdd: invalid argument count");
        return LIBRARY_FUNCTION_ERROR;
    }

    SocketList socketList = (SocketList)MArgument_getInteger(Args[0]);
    SocketObject *socketObject = MArgument_getSocketObject(libData, Args[1]);

    if (!socket_list_add(socketList, *socketObject)) {
        libData->Message("socketListAdd: allocation failed");
        return LIBRARY_FUNCTION_ERROR;
    }

    return LIBRARY_NO_ERROR;
}


DLLEXPORT int socketListGetAll(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    (void)Argc;
    SocketList socketList = (SocketList)MArgument_getInteger(Args[0]);
    const mint length = (mint)socketList->length;
    const mint dimensions[2] = {length, 2};

    MTensor socketsTensor;
    libData->MTensor_new(MType_Integer, 2, dimensions, &socketsTensor);
    mint *socketsData = libData->MTensor_getIntegerData(socketsTensor);

    for (size_t i = 0; i < socketList->length; i++) {
        SOCKET_TYPE socketType;
        switch (socketList->sockets[i].role)
        {
        case SOCKET_ROLE_LISTENER:
            socketType = (socketList->sockets[i].protocol == SOCKET_PROTOCOL_UDP) ? UDP_SERVER : TCP_SERVER;
            break;
        case SOCKET_ROLE_CONNECTED:
            socketType = (socketList->sockets[i].protocol == SOCKET_PROTOCOL_UDP) ? UDP_CLIENT : TCP_CLIENT;
            break;
        case SOCKET_ROLE_ACCEPTED:
            socketType = TCP_ACCEPTED;
            break;
        case SOCKET_ROLE_INTERRUPTER:
        default:
            socketType = INTERUPTER;
            break;
        }

        socketsData[2 * i] = socketList->sockets[i].socket;
        socketsData[2 * i + 1] = socketType;
    }

    MArgument_setMTensor(Res, socketsTensor);
    return LIBRARY_NO_ERROR;
}


DLLEXPORT int socketListPrune(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    (void)libData;
    (void)Argc;
    (void)Res;
    SocketList socketList = (SocketList)MArgument_getInteger(Args[0]);
    socket_list_prune(socketList);
    return LIBRARY_NO_ERROR;
}


DLLEXPORT int socketListDelete(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    (void)libData;
    (void)Argc;
    (void)Res;
    SocketList socketList = (SocketList)MArgument_getInteger(Args[0]);
    socket_list_free(socketList);
    return LIBRARY_NO_ERROR;
}

bool socket_list_add(SocketList socketList, SocketObject socketObject)
{
    if (!socketList) {
        return false;
    }

    if (socketList->length == socketList->capacity) {
        size_t newCapacity = socketList->capacity * 2;
        SocketObject *newSockets = malloc(sizeof(SocketObject) * newCapacity);
        if (!newSockets) {
            return false;
        }

        POLL_FD *newPollfds = malloc(sizeof(POLL_FD) * newCapacity);
        if (!newPollfds) {
            free(newSockets);
            return false;
        }

        memcpy(newSockets, socketList->sockets, sizeof(SocketObject) * socketList->length);
        memcpy(newPollfds, socketList->pollfds, sizeof(POLL_FD) * socketList->length);

        free(socketList->sockets);
        free(socketList->pollfds);

        socketList->sockets = newSockets;
        socketList->pollfds = newPollfds;
        socketList->capacity = newCapacity;
    }

    socketList->sockets[socketList->length] = socketObject;
    socketList->pollfds[socketList->length].fd = (SOCKET)socketObject.socket;
    socketList->pollfds[socketList->length].events = 0;
    socketList->pollfds[socketList->length].revents = 0;
    socketList->length++;
    return true;
}


void socket_list_prune(SocketList socketList)
{
    size_t j = 0;
    for (size_t i = 0; i < socketList->length; i++) {
        if (socketList->sockets[i].socket != (int64_t)INVALID_SOCKET) {
            if (i != j) {
                socketList->sockets[j] = socketList->sockets[i];
                socketList->pollfds[j] = socketList->pollfds[i];
            }
            j++;
        }
    }
    socketList->length = j;
}


void socket_list_free(SocketList socketList)
{
    free(socketList->sockets);
    free(socketList->pollfds);
    free(socketList);
}