#include "async.h"


static bool raiseError(WolframLibraryData libData, mint taskId, SOCKET socketId, int error)
{
    DataStore store = libData->ioLibraryFunctions->createDataStore();

    if (!store) {
        return false;
    }

    libData->ioLibraryFunctions->DataStore_addInteger(store, (mint)socketId);
    libData->ioLibraryFunctions->DataStore_addInteger(store, (mint)error);
    libData->ioLibraryFunctions->raiseAsyncEvent(taskId, "Error", store);

    return true;
}


static bool raiseAccepted(WolframLibraryData libData, mint taskId, SOCKET socketId, SOCKET acceptedSocket)
{
    DataStore store = libData->ioLibraryFunctions->createDataStore();

    if (!store) {
        return false;
    }

    libData->ioLibraryFunctions->DataStore_addInteger(store, (mint)socketId);
    libData->ioLibraryFunctions->DataStore_addInteger(store, (mint)acceptedSocket);
    libData->ioLibraryFunctions->raiseAsyncEvent(taskId, "Accepted", store);

    return true;
}


static bool raiseReceived(WolframLibraryData libData, mint taskId, SOCKET socketId, MNumericArray bytes)
{
    DataStore store = libData->ioLibraryFunctions->createDataStore();

    if (!store) {
        return false;
    }

    libData->ioLibraryFunctions->DataStore_addInteger(store, (mint)socketId);
    libData->ioLibraryFunctions->DataStore_addMNumericArray(store, bytes);
    libData->ioLibraryFunctions->raiseAsyncEvent(taskId, "Received", store);

    return true;
}


static bool raiseReceivedFrom(WolframLibraryData libData, mint taskId, SOCKET socketId, MNumericArray bytes, char *endpoint)
{
    DataStore store = libData->ioLibraryFunctions->createDataStore();

    if (!store) {
        return false;
    }

    libData->ioLibraryFunctions->DataStore_addInteger(store, (mint)socketId);
    libData->ioLibraryFunctions->DataStore_addString(store, endpoint);
    libData->ioLibraryFunctions->DataStore_addMNumericArray(store, bytes);
    libData->ioLibraryFunctions->raiseAsyncEvent(taskId, "ReceivedFrom", store);

    return true;
}


static bool raiseClosed(WolframLibraryData libData, mint taskId, SOCKET socketId)
{
    DataStore store = libData->ioLibraryFunctions->createDataStore();

    if (!store) {
        return false;
    }

    libData->ioLibraryFunctions->DataStore_addInteger(store, (mint)socketId);
    libData->ioLibraryFunctions->raiseAsyncEvent(taskId, "Closed", store);

    return true;
}


static void socketsPollLoop(mint taskId, void *taskArgs)
{
    SocketsPollArgs args = taskArgs;
    WolframLibraryData libData = args->libData;
    SocketList socketList = args->socketList;

    POLL_FD *fds = NULL;
    size_t length = 0;

    bool needPrune = false;
    bool failed = false;

    int nativeEvents = convert_wl_to_native_events(args->eventsMask);
    BYTE buffer[65536];

    while (libData->ioLibraryFunctions->asynchronousTaskAliveQ(taskId)) {
        if (needPrune) {
            socket_list_prune(socketList);
            needPrune = false;
        }

        bool filled = fill_fds_from_socket_list(socketList, &fds, &length, nativeEvents);

        if (!filled) {
            failed = true;
            break;
        }

        int count = sockets_poll(fds, (mint)length, args->timeout);
        int nativeError = count < 0 ? GETSOCKETERRNO() : 0;

        if (count < 0) {
            for (size_t i = 0; i < length; i++) {
                int socketType;
                socklen_t typeLength = sizeof(socketType);
                int status = getsockopt(fds[i].fd, SOL_SOCKET, SO_TYPE, (char *)&socketType, &typeLength);

                if (status == SOCKET_ERROR) {
                    if (!raiseError(libData, taskId, fds[i].fd, nativeError)) {
                        continue;
                    }

                    socketList->sockets[i] = INVALID_SOCKET;
                    needPrune = true;
                }
            }

            if (needPrune) {
                continue;
            }

            if (!raiseError(libData, taskId, -1, nativeError)) {
                break;
            }

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
            bool eventFailed = false;
            SOCKET acceptedSocket = INVALID_SOCKET;
            int error = 0;
            int received = -1;
            MNumericArray bytes = NULL;
            struct sockaddr_storage address = {0};
            char *endpoint = NULL;
            bool readable = (mask & WL_POLLIN) != 0;
            bool invalid = (mask & WL_POLLNVAL) != 0;
            bool socketError = (mask & WL_POLLERR) != 0;
            bool hangup = (mask & WL_POLLHUP) != 0;

            if (readable) {
                switch (role) {
                    case SOCKET_ROLE_TCP_BOUND:
                        acceptedSocket = accept(socketId, NULL, NULL);

                        if (ISVALIDSOCKET(acceptedSocket)) {
                            bool added = socket_list_add(socketList, acceptedSocket, SOCKET_ROLE_TCP_ACCEPTED);

                            if (added) {
                                if (!raiseAccepted(libData, taskId, socketId, acceptedSocket)) {
                                    eventFailed = true;
                                }
                            } else {
                                CLOSESOCKET(acceptedSocket);
                                error = LIBRARY_MEMORY_ERROR;

                                if (!raiseError(libData, taskId, socketId, error)) {
                                    eventFailed = true;
                                }
                            }
                        } else {
                            error = GETSOCKETERRNO();

                            if (!is_would_block_err(error)) {
                                if (!raiseError(libData, taskId, socketId, error)) {
                                    eventFailed = true;
                                }
                            }
                        }
                        break;

                    case SOCKET_ROLE_TCP_ACCEPTED:
                    case SOCKET_ROLE_TCP_CONNECTED:
                        received = recv(socketId, (char *)buffer, sizeof(buffer), 0);

                        if (received > 0) {
                            mint size = received;
                            int status = libData->numericarrayLibraryFunctions->MNumericArray_new(MNumericArray_Type_UBit8, 1, &size, &bytes);

                            if (status != LIBRARY_NO_ERROR) {
                                eventFailed = true;
                                break;
                            }

                            BYTE *data = libData->numericarrayLibraryFunctions->MNumericArray_getData(bytes);
                            memcpy(data, buffer, (size_t)received);

                            if (!raiseReceived(libData, taskId, socketId, bytes)) {
                                eventFailed = true;
                            }
                        } else if (received == 0) {
                            removeSocket = true;

                            if (!raiseClosed(libData, taskId, socketId)) {
                                eventFailed = true;
                            }
                        } else {
                            error = GETSOCKETERRNO();

                            if (!is_would_block_err(error)) {
                                removeSocket = true;

                                if (!raiseError(libData, taskId, socketId, error)) {
                                    eventFailed = true;
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

                            if (received > 0 || received == 0) {
                                mint size = received;
                                int status = libData->numericarrayLibraryFunctions->MNumericArray_new(MNumericArray_Type_UBit8, 1, &size, &bytes);

                                if (status != LIBRARY_NO_ERROR) {
                                    eventFailed = true;
                                    break;
                                }

                                if (received > 0) {
                                    BYTE *data = libData->numericarrayLibraryFunctions->MNumericArray_getData(bytes);
                                    memcpy(data, buffer, (size_t)received);
                                }

                                endpoint = sockaddr_storage_to_string(address);

                                if (!endpoint) {
                                    libData->numericarrayLibraryFunctions->MNumericArray_free(bytes);
                                    bytes = NULL;

                                    if (!raiseError(libData, taskId, socketId, LIBRARY_FUNCTION_ERROR)) {
                                        eventFailed = true;
                                    }

                                    break;
                                }

                                if (!raiseReceivedFrom(libData, taskId, socketId, bytes, endpoint)) {
                                    eventFailed = true;
                                }
                            } else {
                                error = GETSOCKETERRNO();

                                if (!is_would_block_err(error)) {
                                    removeSocket = true;

                                    if (!raiseError(libData, taskId, socketId, error)) {
                                        eventFailed = true;
                                    }
                                }
                            }
                        }
                        break;

                    default:
                        break;
                }
            } else if (invalid || socketError || hangup) {
                error = (int)mask;
                removeSocket = true;

                if (socketError || invalid) {
                    if (!raiseError(libData, taskId, socketId, error)) {
                        eventFailed = true;
                    }
                } else if (!raiseClosed(libData, taskId, socketId)) {
                    eventFailed = true;
                }
            }

            if (removeSocket) {
                if (ISVALIDSOCKET(socketId)) {
                    CLOSESOCKET(socketId);
                }

                socketList->sockets[i] = INVALID_SOCKET;
                needPrune = true;
            }

            if (bytes && eventFailed) {
                libData->numericarrayLibraryFunctions->MNumericArray_free(bytes);
            }

            if (eventFailed) {
                failed = true;
                break;
            }
        }

        if (failed) {
            break;
        }
    }

    if (failed) {
        DataStore store = libData->ioLibraryFunctions->createDataStore();

        if (store) {
            libData->ioLibraryFunctions->DataStore_addInteger(store, -1);
            libData->ioLibraryFunctions->DataStore_addInteger(store, LIBRARY_MEMORY_ERROR);
            libData->ioLibraryFunctions->raiseAsyncEvent(taskId, "Error", store);
        }
    }

    free(fds);
    free(args);
}


DLLEXPORT int createSocketsPollLoop(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    if (Argc != 3) {
        libData->Message("createSocketsPollLoop: invalid argument count");
        return LIBRARY_FUNCTION_ERROR;
    }

    SocketList list = (SocketList)(uintptr_t)MArgument_getInteger(Args[0]);
    mint timeout = MArgument_getInteger(Args[1]);
    mint eventsMask = MArgument_getInteger(Args[2]);

    if (!list || timeout < -1) {
        libData->Message("createSocketsPollLoop: invalid socket list or timeout");
        return LIBRARY_FUNCTION_ERROR;
    }

    SocketsPollArgs args = calloc(1, sizeof(struct SocketsPollArgs_st));

    if (!args) {
        libData->Message("createSocketsPollLoop: failed to allocate task arguments");
        return LIBRARY_MEMORY_ERROR;
    }

    args->libData = libData;
    args->socketList = list;
    args->eventsMask = eventsMask;
    args->timeout = timeout;

    mint taskId = libData->ioLibraryFunctions->createAsynchronousTaskWithThread(socketsPollLoop, args);

    if (taskId <= 0) {
        libData->Message("createSocketsPollLoop: failed to create asynchronous task");
        free(args);
        return LIBRARY_FUNCTION_ERROR;
    }

    MArgument_setInteger(Res, taskId);
    return LIBRARY_NO_ERROR;
}
