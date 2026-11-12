#ifndef LIST_H
#define LIST_H


#include "socket.h"


typedef enum {
    INTERUPTER,
    TCP_SERVER,
    UDP_SERVER,
    TCP_CLIENT,
    UDP_CLIENT,
    TCP_ACCEPTED
} SOCKET_TYPE;


typedef struct SocketList_st
{
    SocketObject *sockets;
    POLL_FD *pollfds;
    size_t length;
    size_t capacity;
} *SocketList;


static inline SOCKET_TYPE socket_list_socket_type(SocketObject socketObject)
{
    switch ((SocketRole)socketObject.role) {
    case SOCKET_ROLE_LISTENER:
        return (socketObject.protocol == SOCKET_PROTOCOL_UDP) ? UDP_SERVER : TCP_SERVER;
    case SOCKET_ROLE_CONNECTED:
        return (socketObject.protocol == SOCKET_PROTOCOL_UDP) ? UDP_CLIENT : TCP_CLIENT;
    case SOCKET_ROLE_ACCEPTED:
        return TCP_ACCEPTED;
    case SOCKET_ROLE_INTERRUPTER:
    default:
        return INTERUPTER;
    }
}


bool socket_list_add(SocketList socketList, SocketObject socketObject);


void socket_list_prune(SocketList socketList);


void socket_list_free(SocketList socketList);


#endif