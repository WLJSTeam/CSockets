#include "list.h"


bool fill_fds_from_socket_list(SocketList socketList, POLL_FD **fds, size_t *length, int events)
{
    if (!socketList || !fds || !length) {
        return false;
    }

    size_t newLength = socketList->length;
    size_t maxLength = SIZE_MAX / sizeof(POLL_FD);

    if (newLength > maxLength || newLength > INT_MAX) {
        return false;
    }

    if (newLength != *length) {
        POLL_FD *newFds = NULL;

        if (newLength > 0) {
            newFds = realloc(*fds, newLength * sizeof(POLL_FD));

            if (!newFds) {
                return false;
            }
        } else {
            free(*fds);
        }

        *fds = newFds;
        *length = newLength;
    }

    if (newLength > 0 && !*fds) {
        return false;
    }

    for (size_t i = 0; i < newLength; i++) {
        (*fds)[i].fd = socketList->sockets[i];
        (*fds)[i].events = events;
        (*fds)[i].revents = 0;

        if (socketList->roles[i] == SOCKET_ROLE_UNDEFINED) {
            (*fds)[i].events = 0;
        }
    }

    return true;
}


bool socket_list_add(SocketList list, SOCKET socketId, SOCKET_ROLE role)
{
    if (!list) {
        return false;
    }

    for (size_t i = 0; i < list->length; i++) {
        if (list->sockets[i] == socketId) {
            return true;
        }
    }

    if (list->length == INT_MAX) {
        return false;
    }

    if (list->length == list->capacity) {
        size_t capacity;
        SOCKET *sockets;
        SOCKET_ROLE *roles;

        if (list->capacity) {
            capacity = list->capacity * 2;
        } else {
            capacity = 8;
        }

        if (capacity < list->capacity) {
            return false;
        }

        size_t maxSockets = SIZE_MAX / sizeof(SOCKET);
        size_t maxRoles = SIZE_MAX / sizeof(SOCKET_ROLE);

        if (capacity > maxSockets || capacity > maxRoles) {
            return false;
        }

        sockets = malloc(capacity * sizeof(SOCKET));

        if (!sockets) {
            return false;
        }

        roles = malloc(capacity * sizeof(SOCKET_ROLE));

        if (!roles) {
            free(sockets);
            return false;
        }

        if (list->length > 0) {
            memcpy(sockets, list->sockets, list->length * sizeof(SOCKET));
            memcpy(roles, list->roles, list->length * sizeof(SOCKET_ROLE));
        }

        free(list->sockets);
        free(list->roles);

        list->sockets = sockets;
        list->roles = roles;
        list->capacity = capacity;
    }

    list->sockets[list->length] = socketId;
    list->roles[list->length] = role;
    list->length++;
    return true;
}


bool socket_list_prune(SocketList list)
{
    if (!list) {
        return false;
    }

    size_t count = 0;

    for (size_t i = 0; i < list->length; i++) {
        bool valid = ISVALIDSOCKET(list->sockets[i]);

        if (valid) {
            list->sockets[count] = list->sockets[i];
            list->roles[count] = list->roles[i];
            count++;
        }
    }

    list->length = count;
    return true;
}


DLLEXPORT int socketListCreate(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    if (Argc != 2) {
        libData->Message("socketListCreate: invalid argument count");
        return LIBRARY_FUNCTION_ERROR;
    }

    MTensor socketIds = MArgument_getMTensor(Args[0]);
    MTensor socketRoles = MArgument_getMTensor(Args[1]);

    mint idsType = libData->MTensor_getType(socketIds);
    mint rolesType = libData->MTensor_getType(socketRoles);
    mint idsRank = libData->MTensor_getRank(socketIds);
    mint rolesRank = libData->MTensor_getRank(socketRoles);

    if (idsType != MType_Integer || rolesType != MType_Integer || idsRank != 1 || rolesRank != 1) {
        libData->Message("socketListCreate: expected integer vectors");
        return LIBRARY_FUNCTION_ERROR;
    }

    mint length = libData->MTensor_getFlattenedLength(socketIds);
    mint rolesLength = libData->MTensor_getFlattenedLength(socketRoles);

    if (length != rolesLength || length > INT_MAX) {
        libData->Message("socketListCreate: invalid vector lengths");
        return LIBRARY_FUNCTION_ERROR;
    }

    mint *ids = libData->MTensor_getIntegerData(socketIds);
    mint *roles = libData->MTensor_getIntegerData(socketRoles);
    SocketList list = calloc(1, sizeof(struct SocketList_st));

    if (!list) {
        libData->Message("socketListCreate: failed to allocate socket list");
        return LIBRARY_MEMORY_ERROR;
    }

    for (mint i = 0; i < length; i++) {
        SOCKET socketId = (SOCKET)ids[i];
        SOCKET_ROLE role = (SOCKET_ROLE)roles[i];
        bool valid = ISVALIDSOCKET(socketId);
        bool added = false;

        if (valid) {
            added = socket_list_add(list, socketId, role);
        }

        if (!added) {
            libData->Message("socketListCreate: invalid socket or failed to add socket to list");
            free(list->sockets);
            free(list->roles);
            free(list);
            return LIBRARY_FUNCTION_ERROR;
        }
    }

    mint socketListId = (mint)(uintptr_t)list;
    MArgument_setInteger(Res, socketListId);
    return LIBRARY_NO_ERROR;
}


DLLEXPORT int socketListAdd(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    if (Argc != 3) {
        libData->Message("socketListAdd: invalid argument count");
        return LIBRARY_FUNCTION_ERROR;
    }

    SocketList list = (SocketList)(uintptr_t)MArgument_getInteger(Args[0]);
    SOCKET socketId = (SOCKET)MArgument_getInteger(Args[1]);
    SOCKET_ROLE role = (SOCKET_ROLE)MArgument_getInteger(Args[2]);

    bool valid = ISVALIDSOCKET(socketId);

    if (!valid) {
        libData->Message("socketListAdd: invalid socket");
        return LIBRARY_FUNCTION_ERROR;
    }

    bool added = socket_list_add(list, socketId, role);

    if (!added) {
        libData->Message("socketListAdd: failed to add socket to list");
        return LIBRARY_FUNCTION_ERROR;
    }

    return LIBRARY_NO_ERROR;
}


DLLEXPORT int socketListGetAll(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    if (Argc != 1) {
        libData->Message("socketListGetAll: invalid argument count");
        return LIBRARY_FUNCTION_ERROR;
    }

    SocketList list = (SocketList)(uintptr_t)MArgument_getInteger(Args[0]);

    if (!list) {
        libData->Message("socketListGetAll: invalid socket list");
        return LIBRARY_FUNCTION_ERROR;
    }

    mint length = (mint)list->length;
    MTensor socketsTensor;
    int status = libData->MTensor_new(MType_Integer, 1, &length, &socketsTensor);

    if (status) {
        libData->Message("socketListGetAll: failed to allocate socket tensor");
        return LIBRARY_MEMORY_ERROR;
    }

    if (length > 0) {
        mint *data = libData->MTensor_getIntegerData(socketsTensor);

        for (mint i = 0; i < length; i++) {
            data[i] = (mint)list->sockets[i];
        }
    }

    MArgument_setMTensor(Res, socketsTensor);
    return LIBRARY_NO_ERROR;
}


DLLEXPORT int socketListPrune(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    if (Argc != 1) {
        libData->Message("socketListPrune: invalid argument count");
        return LIBRARY_FUNCTION_ERROR;
    }

    SocketList list = (SocketList)(uintptr_t)MArgument_getInteger(Args[0]);

    bool pruned = socket_list_prune(list);

    if (!pruned) {
        libData->Message("socketListPrune: invalid socket list");
        return LIBRARY_FUNCTION_ERROR;
    }

    return LIBRARY_NO_ERROR;
}


DLLEXPORT int socketListDelete(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    if (Argc != 1) {
        libData->Message("socketListDelete: invalid argument count");
        return LIBRARY_FUNCTION_ERROR;
    }

    SocketList list = (SocketList)(uintptr_t)MArgument_getInteger(Args[0]);

    if (!list) {
        libData->Message("socketListDelete: invalid socket list");
        return LIBRARY_FUNCTION_ERROR;
    }

    free(list->sockets);
    free(list->roles);
    free(list);
    return LIBRARY_NO_ERROR;
}
