#include "async.h"


void socketsSelectTask(mint taskId, void *taskArgs) {
    SocketsSelectArgs socketsSelectTaskArgs = (SocketsSelectArgs)taskArgs;
    WolframLibraryData libData = socketsSelectTaskArgs->libData;
    SOCKET *sockets = socketsSelectTaskArgs->sockets;
    size_t length = socketsSelectTaskArgs->length;
    mint timeout = socketsSelectTaskArgs->timeout;

    SOCKET socketId;
    SOCKET maxfd;
    MTensor readySockets;
    mint dims;
    struct timeval tv = new_tv(timeout);

    fd_set readfd;
    FD_ZERO(&readfd);
    maxfd = fill_fd_set_from_array(&readfd, sockets, length, 0);

    int result = select((int)(maxfd + 1), &readfd, NULL, NULL, &tv);
    if (result >= 0) {
        mint dims = (mint)result;
        libData->MTensor_new(MType_Integer, 1, &dims, &readySockets);

        filter_fd_set_to_tensor(libData, &readfd, sockets, readySockets, length);

        DataStore dataStore;
        libData->ioLibraryFunctions->createDataStore();
        libData->ioLibraryFunctions->DataStore_addMTensor(dataStore, readySockets);
        libData->ioLibraryFunctions->raiseAsyncEvent(taskId, "Selected", dataStore);
        libData->MTensor_free(readySockets);
    }

    free(sockets);
}


DLLEXPORT int socketsSelectAsync(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res) {
    MTensor socketIds = MArgument_getMTensor(Args[0]);     // list of sockets
    size_t length = (size_t)MArgument_getInteger(Args[1]); // number of sockets
    int timeout = (int)MArgument_getInteger(Args[2]);      // timeout in microseconds

    SOCKET *sockets = malloc(length * sizeof(SOCKET));
    copy_tensor_to_socket_array(libData, socketIds, sockets, length);

    SocketsSelectArgs taskArgs = malloc(sizeof(struct SocketsSelectArgs_st));

    taskArgs->libData = libData;
    taskArgs->sockets = sockets;
    taskArgs->length = length;
    taskArgs->timeout = timeout;

    mint taskId = libData->ioLibraryFunctions->createAsynchronousTaskWithThread(socketsSelectTask, (void *)taskArgs);

    MArgument_setInteger(Res, taskId);
    return LIBRARY_NO_ERROR;
}


void socketsPollLoop(mint taskId, void *taskArgs) {
    ServerLoopArgs args = (ServerLoopArgs)taskArgs;

    SocketList socketList = args->socketList;

    WolframLibraryData libData = args->libData;
    mint bufferSize = args->bufferSize;
    BYTE *buffer = malloc(bufferSize);
    mint timeout = args->timeout;
    mint eventsMask = args->eventsMask;
    int nativeEvents = convert_wl_to_native_events(eventsMask);

    int result;
    mint dims;
    int recvResult;
    SOCKET acceptedSocketId;
    MNumericArray byteArray;
    DataStore dataStore;

    while (libData->ioLibraryFunctions->asynchronousTaskAliveQ(taskId))
    {
        size_t length = socketList->length;

        for (size_t i = 0; i < length; i++) {
            POLL_FD *pollfd = &socketList->pollfds[i];
            pollfd->events = nativeEvents;
            pollfd->revents = 0;
        }

        POLL_FD *pollfds = socketList->pollfds;
        printf("Polling...\n");
        result = sockets_poll(pollfds, length, timeout);
        if (result > 0) {
            for (size_t i = 0; i < length; i++) {
                mint wl_revents = convert_native_to_wl_events(pollfds[i].revents);
                SOCKET socketId = pollfds[i].fd;
                SOCKET_TYPE socketType = socketList->sockettypes[i];

                if (wl_revents & (WL_POLLERR | WL_POLLHUP | WL_POLLNVAL)) {
                    CLOSESOCKET(socketId);

                    dataStore = libData->ioLibraryFunctions->createDataStore();
                    libData->ioLibraryFunctions->DataStore_addInteger(dataStore, (mint)socketId);
                    libData->ioLibraryFunctions->DataStore_addInteger(dataStore, (mint)socketType);
                    libData->ioLibraryFunctions->DataStore_addInteger(dataStore, (mint)socketId);
                    libData->ioLibraryFunctions->DataStore_addInteger(dataStore, TCP_CLIENT);
                    libData->ioLibraryFunctions->raiseAsyncEvent(taskId, "Closed", dataStore);

                    pollfds[i].fd = INVALID_SOCKET;
                    socket_list_prune(socketList);
                    continue;
                }

                if (wl_revents && WL_POLLIN) {
                    dataStore = libData->ioLibraryFunctions->createDataStore();
                    libData->ioLibraryFunctions->DataStore_addInteger(dataStore, (mint)socketId);
                    libData->ioLibraryFunctions->DataStore_addInteger(dataStore, (mint)socketType);

                    if (socketType == TCP_SERVER) {
                        printf("Accept event on %d\n", socketId);
                        acceptedSocketId = accept(socketId, NULL, NULL);
                        socket_list_add(socketList, acceptedSocketId, TCP_CLIENT);
                        libData->ioLibraryFunctions->DataStore_addInteger(dataStore, (mint)acceptedSocketId);
                        libData->ioLibraryFunctions->DataStore_addInteger(dataStore, TCP_CLIENT);
                        libData->ioLibraryFunctions->raiseAsyncEvent(taskId, "Accepted", dataStore);
                    }

                    if (socketType == TCP_CLIENT) {
                        printf("Received event on %d\n");
                        int recvResult = recv(socketId, buffer, bufferSize, 0);
                        if (recvResult > 0) {
                            dims = (mint)recvResult;
                            libData->numericarrayLibraryFunctions->MNumericArray_new(MNumericArray_Type_UBit8, 1, &dims, &byteArray);

                            BYTE *array = libData->numericarrayLibraryFunctions->MNumericArray_getData(byteArray);
                            memcpy(array, buffer, recvResult);

                            libData->ioLibraryFunctions->DataStore_addMNumericArray(dataStore, byteArray);
                            libData->ioLibraryFunctions->raiseAsyncEvent(taskId, "Received", dataStore);
                        } else if (recvResult == 0) {
                            libData->ioLibraryFunctions->DataStore_addInteger(dataStore, (mint)socketId);
                            libData->ioLibraryFunctions->DataStore_addInteger(dataStore, TCP_CLIENT);
                            libData->ioLibraryFunctions->raiseAsyncEvent(taskId, "Closed", dataStore);
                            socket_list_prune(socketList);
                        } else {
                            libData->ioLibraryFunctions->DataStore_addInteger(dataStore, GETSOCKETERRNO());
                            libData->ioLibraryFunctions->raiseAsyncEvent(taskId, "Error", dataStore);
                            socket_list_prune(socketList);
                        }
                    }
                }
            }
        }
    }
}


DLLEXPORT int createSocketsPollLoop(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res) {
    SocketList socketList = (SocketList)MArgument_getInteger(Args[0]);
    mint bufferSize = MArgument_getInteger(Args[1]);
    mint timeout = MArgument_getInteger(Args[2]);
    mint eventsMask = MArgument_getInteger(Args[3]);

    ServerLoopArgs serverLoopArgs = malloc(sizeof(struct ServerLoopArgs_st));
    serverLoopArgs->libData = libData;
    serverLoopArgs->socketList = socketList;
    serverLoopArgs->bufferSize = bufferSize;
    serverLoopArgs->timeout = timeout;
    serverLoopArgs->eventsMask = eventsMask;

    printf("Creating polling task...\n");
    mint taskId = libData->ioLibraryFunctions->createAsynchronousTaskWithThread(socketsPollLoop, (void *)serverLoopArgs);

    MArgument_setInteger(Res, taskId);
    return LIBRARY_NO_ERROR;
}