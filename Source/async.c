#include "async.h"


static void raiseError(WolframLibraryData libData, mint taskId, SOCKET socketId, int error)
{
    DataStore store = libData->ioLibraryFunctions->createDataStore();

    if (!store) {
        libData->Message("socketPollLoop: failed to raise Error event");
        return;
    }

    libData->ioLibraryFunctions->DataStore_addInteger(store, (mint)socketId);
    libData->ioLibraryFunctions->DataStore_addInteger(store, (mint)error);
    libData->ioLibraryFunctions->raiseAsyncEvent(taskId, "Error", store);
}


static void raiseAccepted(WolframLibraryData libData, mint taskId, SOCKET socketId, SOCKET acceptedSocket)
{
    DataStore store = libData->ioLibraryFunctions->createDataStore();

    if (!store) {
        libData->Message("socketPollLoop: failed to raise Accepted event");
        return;
    }

    libData->ioLibraryFunctions->DataStore_addInteger(store, (mint)socketId);
    libData->ioLibraryFunctions->DataStore_addInteger(store, (mint)acceptedSocket);
    libData->ioLibraryFunctions->raiseAsyncEvent(taskId, "Accepted", store);
}


static void raiseReceived(WolframLibraryData libData, mint taskId, SOCKET socketId, BYTE *bytes, int length)
{
    mint size = (mint)length;
    MNumericArray array = NULL;
    int status = libData->numericarrayLibraryFunctions->MNumericArray_new(MNumericArray_Type_UBit8, 1, &size, &array);

    if (status != LIBRARY_NO_ERROR) {
        libData->Message("socketPollLoop: failed to allocate byte array for Received event");
        return;
    }

    if (length > 0) {
        BYTE *data = libData->numericarrayLibraryFunctions->MNumericArray_getData(array);
        memcpy(data, bytes, length);
    }

    DataStore store = libData->ioLibraryFunctions->createDataStore();

    if (!store) {
        libData->numericarrayLibraryFunctions->MNumericArray_free(array);
        libData->Message("socketPollLoop: failed to raise Received event");
        return;
    }

    libData->ioLibraryFunctions->DataStore_addInteger(store, (mint)socketId);
    libData->ioLibraryFunctions->DataStore_addMNumericArray(store, array);
    libData->ioLibraryFunctions->raiseAsyncEvent(taskId, "Received", store);
}


static void raiseReceivedFrom(WolframLibraryData libData, mint taskId, SOCKET socketId, BYTE *bytes, int length, char *endpoint)
{
    MNumericArray array = NULL;

    if (length > 0) {
        mint size = (mint)length;
        int status = libData->numericarrayLibraryFunctions->MNumericArray_new(MNumericArray_Type_UBit8, 1, &size, &array);

        if (status != LIBRARY_NO_ERROR) {
            libData->Message("socketPollLoop: failed to allocate byte array for ReceivedFrom event");
            return;
        }

        BYTE *data = libData->numericarrayLibraryFunctions->MNumericArray_getData(array);
        memcpy(data, bytes, length);
    }

    DataStore store = libData->ioLibraryFunctions->createDataStore();

    if (!store) {
        if (array) {
            libData->numericarrayLibraryFunctions->MNumericArray_free(array);
        }

        libData->Message("socketPollLoop: failed to raise ReceivedFrom event");
        return;
    }

    libData->ioLibraryFunctions->DataStore_addInteger(store, (mint)socketId);
    libData->ioLibraryFunctions->DataStore_addString(store, endpoint);

    if (array) {
        libData->ioLibraryFunctions->DataStore_addMNumericArray(store, array);
    }

    libData->ioLibraryFunctions->raiseAsyncEvent(taskId, "ReceivedFrom", store);
}


static void raiseClosed(WolframLibraryData libData, mint taskId, SOCKET socketId)
{
    DataStore store = libData->ioLibraryFunctions->createDataStore();

    if (!store) {
        libData->Message("socketPollLoop: failed to raise Closed event");
        return;
    }

    libData->ioLibraryFunctions->DataStore_addInteger(store, (mint)socketId);
    libData->ioLibraryFunctions->raiseAsyncEvent(taskId, "Closed", store);
}


static void socketPollLoop(mint taskId, void *taskArgs)
{
    SocketPollLoopArgs args = taskArgs;
    WolframLibraryData libData = args->libData;
    socket_list *socketList = args->socketList;

    POLL_FD *fds = NULL;
    size_t length = 0;

    bool needPrune = false;

    int nativeEvents = convert_wl_to_native_events(args->eventsMask);
    BYTE buffer[65536];

    while (true) {
        bool alive = libData->ioLibraryFunctions->asynchronousTaskAliveQ(taskId);

        if (!alive) {
            break;
        }

        if (needPrune) {
            socket_list_prune(socketList);
            needPrune = false;
        }

        bool filled = socket_list_to_poll_fd(socketList, &fds, &length, nativeEvents);

        if (!filled) {
            libData->Message("socketPollLoop: failed to fill poll descriptors");
            break;
        }

        if (length == 0) {
            break;
        }

        int count = sockets_poll(fds, (mint)length, args->timeout);

        if (count < 0) {
            int nativeError = GETSOCKETERRNO();

            for (size_t i = 0; i < length; i++) {
                int socketType;
                socklen_t typeLength = sizeof(socketType);
                int status = getsockopt(fds[i].fd, SOL_SOCKET, SO_TYPE, (char *)&socketType, &typeLength);

                if (status == SOCKET_ERROR) {
                    raiseError(libData, taskId, fds[i].fd, nativeError);
                    socketList->sockets[i] = INVALID_SOCKET;
                    needPrune = true;
                }
            }

            if (needPrune) {
                continue;
            }

            raiseError(libData, taskId, -1, nativeError);
            break;
        }

        for (size_t i = 0; i < length; i++) {
            SOCKET socketId = fds[i].fd;
            SOCKET_ROLE role = socketList->roles[i];
            mint mask = convert_native_to_wl_events(fds[i].revents);

            if (mask == 0 || role == SOCKET_ROLE_TCP_UNSPEC || role == SOCKET_ROLE_UDP_UNSPEC) {
                continue;
            }

            bool removeSocket = false;
            int received = -1;
            struct sockaddr_storage address = {0};

            bool readable = (mask & WL_POLLIN) != 0;
            bool invalid = (mask & WL_POLLNVAL) != 0;
            bool socketError = (mask & WL_POLLERR) != 0;
            bool hangup = (mask & WL_POLLHUP) != 0;

            if (readable) {
                switch (role) {
                    case SOCKET_ROLE_TCP_BOUND:
                        {
                            SOCKET acceptedSocket = accept(socketId, NULL, NULL);
                            bool valid = ISVALIDSOCKET(acceptedSocket);

                            if (valid) {
                                bool added = socket_list_add(socketList, acceptedSocket, SOCKET_ROLE_TCP_ACCEPTED);

                                if (added) {
                                    raiseAccepted(libData, taskId, socketId, acceptedSocket);
                                } else {
                                    CLOSESOCKET(acceptedSocket);
                                    raiseError(libData, taskId, socketId, LIBRARY_MEMORY_ERROR);
                                }
                            } else {
                                int error = GETSOCKETERRNO();
                                bool wouldBlock = is_would_block_err(error);

                                if (!wouldBlock) {
                                    raiseError(libData, taskId, socketId, error);
                                }
                            }
                        }
                        break;

                    case SOCKET_ROLE_TCP_ACCEPTED:
                    case SOCKET_ROLE_TCP_CONNECTED:
                        {
                            received = recv(socketId, (char *)buffer, sizeof(buffer), 0);

                            if (received > 0) {
                                raiseReceived(libData, taskId, socketId, buffer, received);
                            } else if (received == 0) {
                                removeSocket = true;
                                raiseClosed(libData, taskId, socketId);
                            } else {
                                int error = GETSOCKETERRNO();
                                bool wouldBlock = is_would_block_err(error);

                                if (!wouldBlock) {
                                    removeSocket = true;
                                    raiseError(libData, taskId, socketId, error);
                                }
                            }
                        }
                        break;

                    case SOCKET_ROLE_UDP_BOUND:
                    case SOCKET_ROLE_UDP_CONNECTED:
                        {
                            socklen_t addressLength = sizeof(address);
                            received = recvfrom(socketId, (char *)buffer, sizeof(buffer), 0,
                                (struct sockaddr *)&address, &addressLength);

                            if (received >= 0) {
                                char *endpoint = sockaddr_storage_to_string(address);

                                if (endpoint) {
                                    raiseReceivedFrom(libData, taskId, socketId, buffer, received, endpoint);
                                } else {
                                    raiseError(libData, taskId, socketId, LIBRARY_FUNCTION_ERROR);
                                }
                            } else {
                                int error = GETSOCKETERRNO();
                                bool wouldBlock = is_would_block_err(error);

                                if (!wouldBlock) {
                                    removeSocket = true;
                                    raiseError(libData, taskId, socketId, error);
                                }
                            }
                        }
                        break;

                    default:
                        break;
                }
            } else if (invalid || socketError || hangup) {
                removeSocket = true;

                if (socketError || invalid) {
                    raiseError(libData, taskId, socketId, (int)mask);
                } else {
                    raiseClosed(libData, taskId, socketId);
                }
            }

            if (removeSocket) {
                bool valid = ISVALIDSOCKET(socketId);

                if (valid) {
                    CLOSESOCKET(socketId);
                }

                socketList->sockets[i] = INVALID_SOCKET;
                needPrune = true;
            }
        }
    }

    free(fds);
    remove_socket_list(socketList);
    free(args);
}


DLLEXPORT int socketPollLoopCreate(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    if (Argc != 4) {
        libData->Message("socketPollLoopCreate: invalid argument count");
        return LIBRARY_FUNCTION_ERROR;
    }

    MTensor socketIds = MArgument_getMTensor(Args[0]);
    MTensor roles = MArgument_getMTensor(Args[1]);
    mint timeout = MArgument_getInteger(Args[2]);
    mint eventsMask = MArgument_getInteger(Args[3]);

    mint idsType = libData->MTensor_getType(socketIds);
    mint rolesType = libData->MTensor_getType(roles);
    mint idsRank = libData->MTensor_getRank(socketIds);
    mint rolesRank = libData->MTensor_getRank(roles);

    if (idsType != MType_Integer || rolesType != MType_Integer || idsRank != 1 || rolesRank != 1) {
        libData->Message("socketPollLoopCreate: expected integer vectors");
        return LIBRARY_FUNCTION_ERROR;
    }

    mint length = libData->MTensor_getFlattenedLength(socketIds);
    mint rolesLength = libData->MTensor_getFlattenedLength(roles);

    if (length != rolesLength || length > INT_MAX || timeout < -1) {
        libData->Message("socketPollLoopCreate: invalid vector lengths or timeout");
        return LIBRARY_FUNCTION_ERROR;
    }

    mint *idsData = libData->MTensor_getIntegerData(socketIds);
    mint *rolesData = libData->MTensor_getIntegerData(roles);

    for (mint i = 0; i < length; i++) {
        bool valid = ISVALIDSOCKET((SOCKET)idsData[i]);
        mint role = rolesData[i];

        if (!valid || role < SOCKET_ROLE_TCP_UNSPEC || role > SOCKET_ROLE_UDP_CONNECTED) {
            libData->Message("socketPollLoopCreate: invalid socket or role");
            return LIBRARY_FUNCTION_ERROR;
        }
    }

    socket_list *list = create_socket_list(idsData, rolesData, (size_t)length);

    if (!list) {
        libData->Message("socketPollLoopCreate: failed to create socket list");
        return LIBRARY_MEMORY_ERROR;
    }

    SocketPollLoopArgs args = calloc(1, sizeof(struct SocketPollLoopArgs_st));

    if (!args) {
        remove_socket_list(list);
        libData->Message("socketPollLoopCreate: failed to allocate task arguments");
        return LIBRARY_MEMORY_ERROR;
    }

    args->libData = libData;
    args->socketList = list;
    args->eventsMask = eventsMask;
    args->timeout = timeout;

    mint taskId = libData->ioLibraryFunctions->createAsynchronousTaskWithThread(socketPollLoop, args);

    if (taskId <= 0) {
        remove_socket_list(list);
        free(args);
        libData->Message("socketPollLoopCreate: failed to create asynchronous task");
        return LIBRARY_FUNCTION_ERROR;
    }

    MArgument_setInteger(Res, taskId);
    return LIBRARY_NO_ERROR;
}
