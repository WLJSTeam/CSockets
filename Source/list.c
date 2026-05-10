#include "list.h"

DLLEXPORT int socketListCreate(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res) {
    MTensor sockets = MArgument_getMTensor(Args[0]);
    mint* socketsData = libData->MTensor_getIntegerData(sockets);
    
    size_t length = (size_t)MArgument_getInteger(Args[1]);

    if (length < 0) {
        return LIBRARY_FUNCTION_ERROR;
    }

    size_t capacity = 1;
    while (capacity < length)
    {
        capacity *= 2;
    }

    SOCKET *socketsArray = malloc(sizeof(SOCKET) * capacity);
    if (!socketsArray) {
        return LIBRARY_FUNCTION_ERROR;
    }

    for (int i = 0; i < length; i++) {
        socketsArray[i] = (SOCKET)socketsData[i];
    }

    SocketList socketList = malloc(sizeof(struct SocketList_st));
    if (!socketList) {
        free(socketsArray);
        return LIBRARY_FUNCTION_ERROR;
    }

    socketList->sockets = socketsArray;
    socketList->length = length;
    socketList->capacity = capacity;

    mint socketListPtr = (mint)(uintptr_t)socketList;
    MArgument_setInteger(Res, socketListPtr);
    return LIBRARY_NO_ERROR;
}

DLLEXPORT int socketListRemove(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res) {
    SocketList socketList = (SocketList)MArgument_getInteger(Args[0]);
    free(socketList->sockets);
    free(socketList);
    return LIBRARY_NO_ERROR;
}

DLLEXPORT int socketListAdd(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res) {
    SocketList socketList = (SocketList)MArgument_getInteger(Args[0]);
    SOCKET socketId = (SOCKET)MArgument_getInteger(Args[1]);
    socket_list_add(socketList, socketId);
    return LIBRARY_NO_ERROR;
}

DLLEXPORT int socketListGetAll(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res) {
    SocketList socketList = (SocketList)MArgument_getInteger(Args[0]);
    SOCKET *sockets = socketList->sockets;
    const mint length = socketList->length;

    MTensor socketsTensor;
    libData->MTensor_new(MType_Integer, 1, &length, &socketsTensor);
    mint *socketsData = libData->MTensor_getIntegerData(socketsTensor);

    for (size_t i = 0; i < length; i++) {
        socketsData[i] = (mint)sockets[i];
    }

    MArgument_setMTensor(Res, socketsTensor);
    return LIBRARY_NO_ERROR;
}

DLLEXPORT int socketListClear(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res) {
    SocketList socketList = (SocketList)MArgument_getInteger(Args[0]);
    socket_list_clear(socketList);
    return LIBRARY_NO_ERROR;
}

void socket_list_add(SocketList socketList, SOCKET socketId) {
    socketList->sockets[socketList->length++] = socketId;
    if (socketList->length == socketList->capacity) {
        socketList->capacity *= 2;
        socketList->sockets = realloc(socketList->sockets, sizeof(SOCKET) * socketList->capacity);
    }
}

void socket_list_clear(SocketList socketList) {
    size_t writeIndex = 0;
    
    for (size_t i = 0; i < socketList->length; i++) {
        SOCKET socketId = socketList->sockets[i];
        
        if (is_valid_socket(socketId)) {
            if (writeIndex != i) {
                socketList->sockets[writeIndex] = socketId;
            }
            writeIndex++;
        }
    }
    
    socketList->length = writeIndex;
    while (socketList->capacity > socketList->length * 2)
    {
        socketList->capacity /= 2;
    }
    socketList->sockets = realloc(socketList->sockets, sizeof(SOCKET) * socketList->capacity);
}