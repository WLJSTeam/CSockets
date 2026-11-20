#ifndef LIST_H
#define LIST_H


#include "socket.h"


typedef struct SocketList_st {
    SOCKET *sockets;
    SOCKET_ROLE *roles;
    size_t capacity;
    size_t length;
} *SocketList;


bool socket_list_add(SocketList list, SOCKET socketId, SOCKET_ROLE role);


bool socket_list_prune(SocketList list);


#endif
