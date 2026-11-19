#ifndef LIST_H
#define LIST_H


#include "socket.h"


typedef struct SocketList_st {
    SOCKET *sockets;
    size_t length;
    size_t capacity;
    size_t references;
    bool deleted;
#ifdef _WIN32
    CRITICAL_SECTION lock;
#else
    pthread_mutex_t lock;
#endif
} *SocketList;


void socket_list_lock(SocketList list);
void socket_list_unlock(SocketList list);
bool socket_list_add(SocketList list, SOCKET socketId);
bool socket_list_retain(SocketList list);
void socket_list_release(SocketList list);
/* Returns an owned copy, allowing polling without holding the list lock. */
int socket_list_snapshot(SocketList list, SOCKET **sockets, mint *length);


#endif
