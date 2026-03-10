#include "async.h"

void socketsSelectTask(mint taskId, void *taskArgs) {
    SocketsSelectArgs socketsSelectTaskArgs = (SocketsSelectArgs)taskArgs;
    WolframLibraryData libData = socketsSelectTaskArgs->libData;
    SOCKET *sockets = socketsSelectTaskArgs->sockets;
    size_t length = socketsSelectTaskArgs->length;
    mint timeout = socketsSelectTaskArgs->timeout;

    SOCKET socketId;
    SOCKET maxFd = 0;

    fd_set readfds;
    FD_ZERO(&readfds);

    for (size_t i = 0; i < length; i++) {
        socketId = sockets[i];
        if (socketId > maxFd) maxFd = socketId;
        FD_SET(socketId, &readfds);
    }

    struct timeval tv;
    tv.tv_sec  = timeout / 1000000;
    tv.tv_usec = timeout % 1000000;

    int result = select((int)(maxFd + 1), &readfds, NULL, NULL, &tv);
    if (result >= 0) {
        mint len = (mint)result;
        MTensor readySocketsTensor;
        libData->MTensor_new(MType_Integer, 1, &len, &readySocketsTensor);
        mint *readySockets = libData->MTensor_getIntegerData(readySocketsTensor);

        int j = 0;
        for (size_t i = 0; i < length; i++) {
            socketId = sockets[i];
            if (FD_ISSET(socketId, &readfds)) {
                readySockets[j] = (mint)socketId;
                j++;
            }
        }

        DataStore dataStore;
        libData->ioLibraryFunctions->createDataStore();
        libData->ioLibraryFunctions->DataStore_addMTensor(dataStore, readySocketsTensor);
        libData->ioLibraryFunctions->raiseAsyncEvent(taskId, "socketsSelectTask", dataStore);
        libData->MTensor_free(readySocketsTensor);
    }

    free(sockets);
}

DLLEXPORT int socketsSelectAsync(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res) {
    MTensor sockets = MArgument_getMTensor(Args[0]); // list of sockets
    size_t length = (size_t)MArgument_getInteger(Args[1]); // number of sockets
    int timeout = (int)MArgument_getInteger(Args[2]); // timeout in microseconds

    SOCKET *socketIds = malloc(length * sizeof(SOCKET));

    mint *socketsData = libData->MTensor_getIntegerData(sockets);
    for(size_t i = 0; i < length; i++) {
        socketIds[i] = (SOCKET)socketsData[i];
    }

    SocketsSelectArgs taskArgs = malloc(sizeof(struct SocketsSelectArgs_st));

    taskArgs->libData = libData;
    taskArgs->sockets = socketIds;
    taskArgs->length = length;
    taskArgs->timeout = timeout;

    mint taskId = libData->ioLibraryFunctions->createAsynchronousTaskWithThread(socketsSelectTask, (void *)taskArgs);

    MArgument_setInteger(Res, taskId);
    return LIBRARY_NO_ERROR;
}

void socketsSelectLoop(mint taskId, void *taskArgs) {
    SocketsSelectLoopArgs args = (SocketsSelectLoopArgs)taskArgs;

    WolframLibraryData libData = args->libData;
    SocketList socketList = args->socketList;
    mint timeout = args->timeout;

    fd_set readfd;
    SOCKET *sockets;
    SOCKET maxfd;
    SOCKET socketId;
    int length;
    mint *readySockets;
    size_t j;
    MTensor readySocketsTensor;
    struct timeval tv;
    mint len;
    DataStore dataStore;

    while (libData->ioLibraryFunctions->asynchronousTaskAliveQ(taskId))
    {
        FD_ZERO(&readfd);
        length = socketList->length;
        sockets = socketList->sockets;

        for (size_t i = 0; i < length; i++) {
            socketId = sockets[i];
            FD_SET(socketId, &readfd);
            if (maxfd < socketId) {
                maxfd = socketId;
            }
        }

        tv.tv_sec  = timeout / 1000000;
        tv.tv_usec = timeout % 1000000;

        int result = select((int)(maxfd + 1), &readfd, NULL, NULL, &tv);
        if (result >= 0) {
            len = (mint)result;
            libData->MTensor_new(MType_Integer, 1, &len, &readySocketsTensor);
            readySockets = libData->MTensor_getIntegerData(readySocketsTensor);
            size_t j = 0;

            for (size_t i = 0; i < length; i++) {
                socketId = sockets[i];
                if (FD_ISSET(socketId, &readfd)) {
                    readySockets[j] = (mint)socketId;
                    j++;
                }
            }

            dataStore = libData->ioLibraryFunctions->createDataStore();
            libData->ioLibraryFunctions->DataStore_addMTensor(dataStore, readySocketsTensor);
            libData->ioLibraryFunctions->raiseAsyncEvent(taskId, "socketsSelectLoopTask", dataStore);
        }
    }

    free(taskArgs);
}

DLLEXPORT int createSocketsSelectLoop(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res) {
    SocketList socketList = (SocketList)MArgument_getInteger(Args[0]); // socket list struct
    mint timeout = MArgument_getInteger(Args[1]);

    SocketsSelectLoopArgs taskArgs = malloc(sizeof(struct SocketsSelectLoopArgs_st));

    taskArgs->libData = libData;
    taskArgs->socketList = socketList;
    taskArgs->timeout = timeout;

    mint taskId = libData->ioLibraryFunctions->createAsynchronousTaskWithThread(socketsSelectLoop, (void *)taskArgs);

    MArgument_setInteger(Res, taskId);
    return LIBRARY_NO_ERROR;
}

void serverLoop(mint taskId, void *taskArgs) {
    ServerLoopArgs args = (ServerLoopArgs)taskArgs;
    WolframLibraryData libData = args->libData;
    SocketList listenSockets = args->listenSockets;
    SocketList clientSockets = args->clientSockets;
    SOCKET interrupter = args->interrupter;
    BYTE *buffer = args->buffer;
    int bufferSize = args->bufferSize;
    mint timeout = args->timeout;

    fd_set readfd;
    SOCKET *sockets;
    SOCKET maxfd;
    SOCKET socketId;
    int length;
    mint *readySockets;
    size_t j;
    MTensor readySocketsTensor;
    struct timeval tv;
    mint len;
    DataStore dataStore;
    int result;

    while (libData->ioLibraryFunctions->asynchronousTaskAliveQ(taskId))
    {
        tv.tv_sec  = timeout / 1000000;
        tv.tv_usec = timeout % 1000000;

        FD_ZERO(&readfd);
        length = listenSockets->length;
        sockets = listenSockets->sockets;

        maxfd = interrupter;
        FD_SET(interrupter, &readfd);

        for (size_t i = 0; i < length; i++) {
            socketId = sockets[i];
            FD_SET(socketId, &readfd);
            if (maxfd < socketId) {
                maxfd = socketId;
            }
        }

        length = clientSockets->length;
        sockets = clientSockets->sockets;

        for (size_t i = 0; i < length; i++) {
            socketId = sockets[i];
            FD_SET(socketId, &readfd);
            if (maxfd < socketId) {
                maxfd = socketId;
            }
        }

        int result = select((int)(maxfd + 1), &readfd, NULL, NULL, &tv);
        if (result >= 0) {
            if (FD_ISSET(interrupter, &readfd)) {
                result = recv(interrupter, (char *)buffer, bufferSize, 0);
                if (result > 0) {

                }
            }
        }
    }

}

DLLEXPORT int createServerLoop(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res) {
    SocketList listenSockets = (SocketList)MArgument_getInteger(Args[0]);
    SocketList clientSockets = (SocketList)MArgument_getInteger(Args[1]);
    SOCKET interrupter = (SOCKET)MArgument_getInteger(Args[2]);
    BYTE *buffer = (char *)MArgument_getInteger(Args[3]);
    int bufferSize = (int)MArgument_getInteger(Args[4]);
    mint timeout = MArgument_getInteger(Args[5]);

    ServerLoopArgs serverLoopArgs = malloc(sizeof(struct ServerLoopArgs_st));
    serverLoopArgs->libData = libData;
    serverLoopArgs->listenSockets = listenSockets;
    serverLoopArgs->clientSockets = clientSockets;
    serverLoopArgs->interrupter = interrupter;
    serverLoopArgs->buffer = buffer;
    serverLoopArgs->bufferSize = bufferSize;
    serverLoopArgs->timeout = timeout;

    mint taskId = libData->ioLibraryFunctions->createAsynchronousTaskWithThread(serverLoop, (void *)serverLoopArgs);

    MArgument_setInteger(Res, taskId);
    return LIBRARY_NO_ERROR;
}