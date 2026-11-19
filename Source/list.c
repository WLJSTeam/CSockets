#include "list.h"


void socket_list_lock(SocketList list)
{
#ifdef _WIN32
    EnterCriticalSection(&list->lock);
#else
    pthread_mutex_lock(&list->lock);
#endif
}


void socket_list_unlock(SocketList list)
{
#ifdef _WIN32
    LeaveCriticalSection(&list->lock);
#else
    pthread_mutex_unlock(&list->lock);
#endif
}


bool socket_list_retain(SocketList list)
{
    if (!list) return false;
    socket_list_lock(list);
    bool alive = !list->deleted;
    if (alive) list->references++;
    socket_list_unlock(list);
    return alive;
}


void socket_list_release(SocketList list)
{
    socket_list_lock(list);
    bool destroy = --list->references == 0;
    socket_list_unlock(list);
    if (destroy) {
#ifdef _WIN32
        DeleteCriticalSection(&list->lock);
#else
        pthread_mutex_destroy(&list->lock);
#endif
        free(list->sockets);
        free(list);
    }
}


bool socket_list_add(SocketList list, SOCKET socketId)
{
    if (!list) return false;
    socket_list_lock(list);
    if (list->deleted) {
        socket_list_unlock(list);
        return false;
    }
    /* A descriptor occurs at most once in a list. */
    for (size_t i = 0; i < list->length; i++) {
        if (list->sockets[i] == socketId) {
            socket_list_unlock(list);
            return true;
        }
    }
    if (list->length == INT_MAX) {
        socket_list_unlock(list);
        return false;
    }
    if (list->length == list->capacity) {
        size_t capacity = list->capacity ? list->capacity * 2 : 8;
        if (capacity < list->capacity || capacity > SIZE_MAX / sizeof(SOCKET)) {
            socket_list_unlock(list);
            return false;
        }
        SOCKET *sockets = realloc(list->sockets, capacity * sizeof(SOCKET));
        if (!sockets) {
            socket_list_unlock(list);
            return false;
        }
        list->sockets = sockets;
        list->capacity = capacity;
    }
    list->sockets[list->length++] = socketId;
    socket_list_unlock(list);
    return true;
}


int socket_list_snapshot(SocketList list, SOCKET **sockets, mint *length)
{
    *sockets = NULL;
    *length = 0;
    if (!list) return LIBRARY_FUNCTION_ERROR;
    socket_list_lock(list);
    if (list->deleted) {
        socket_list_unlock(list);
        return LIBRARY_FUNCTION_ERROR;
    }
    if (list->length) {
        *sockets = malloc(list->length * sizeof(SOCKET));
        if (!*sockets) {
            socket_list_unlock(list);
            return LIBRARY_MEMORY_ERROR;
        }
        memcpy(*sockets, list->sockets, list->length * sizeof(SOCKET));
    }
    *length = (mint)list->length;
    socket_list_unlock(list);
    return LIBRARY_NO_ERROR;
}


DLLEXPORT int socketListCreate(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    if (Argc != 0) return LIBRARY_FUNCTION_ERROR;
    SocketList list = calloc(1, sizeof(struct SocketList_st));
    if (!list) return LIBRARY_MEMORY_ERROR;
#ifdef _WIN32
    InitializeCriticalSection(&list->lock);
#else
    if (pthread_mutex_init(&list->lock, NULL)) {
        free(list);
        return LIBRARY_FUNCTION_ERROR;
    }
#endif
    list->references = 1;
    mint socketListId = (mint)(uintptr_t)list;
    MArgument_setInteger(Res, socketListId);
    return LIBRARY_NO_ERROR;
}


DLLEXPORT int socketListAdd(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    if (Argc != 2) return LIBRARY_FUNCTION_ERROR;
    SocketList list = (SocketList)(uintptr_t)MArgument_getInteger(Args[0]);
    SOCKET socketId = (SOCKET)MArgument_getInteger(Args[1]);
    if (!is_valid_socket(socketId)) return LIBRARY_FUNCTION_ERROR;
    return socket_list_add(list, socketId) ? LIBRARY_NO_ERROR : LIBRARY_FUNCTION_ERROR;
}


DLLEXPORT int socketListGetAll(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    if (Argc != 1) return LIBRARY_FUNCTION_ERROR;
    SocketList list = (SocketList)(uintptr_t)MArgument_getInteger(Args[0]);
    SOCKET *sockets;
    mint length;
    int status = socket_list_snapshot(list, &sockets, &length);
    if (status) return status;
    MTensor socketsTensor;
    status = libData->MTensor_new(MType_Integer, 1, &length, &socketsTensor);
    if (!status) {
        mint *data = libData->MTensor_getIntegerData(socketsTensor);
        for (mint i = 0; i < length; i++) data[i] = (mint)sockets[i];
    }
    free(sockets);
    if (status) return LIBRARY_MEMORY_ERROR;
    MArgument_setMTensor(Res, socketsTensor);
    return LIBRARY_NO_ERROR;
}


DLLEXPORT int socketListPrune(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    if (Argc != 1) return LIBRARY_FUNCTION_ERROR;
    SocketList list = (SocketList)(uintptr_t)MArgument_getInteger(Args[0]);
    if (!list) return LIBRARY_FUNCTION_ERROR;
    socket_list_lock(list);
    size_t count = 0;
    for (size_t i = 0; i < list->length; i++) {
        if (is_valid_socket(list->sockets[i])) list->sockets[count++] = list->sockets[i];
    }
    list->length = count;
    socket_list_unlock(list);
    return LIBRARY_NO_ERROR;
}


/* Deletion releases the list, never the sockets it references. */
DLLEXPORT int socketListDelete(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    if (Argc != 1) return LIBRARY_FUNCTION_ERROR;
    SocketList list = (SocketList)(uintptr_t)MArgument_getInteger(Args[0]);
    if (!list) return LIBRARY_FUNCTION_ERROR;
    socket_list_lock(list);
    list->deleted = true;
    socket_list_unlock(list);
    socket_list_release(list);
    return LIBRARY_NO_ERROR;
}
