#ifndef LIST_H
#define LIST_H


#include "common.h"


typedef enum {
    INTERUPTER,
    TCP_SERVER,
    UDP_SERVER,
    TCP_CLIENT,
    UDP_CLIENT
} SOCKET_TYPE;


typedef struct SocketList_st {
    POLL_FD *pollfds;
    struct addrinfo **addrinfos;
    SOCKET_TYPE *sockettypes;

    mint capacity;
    mint length;
} *SocketList;


SocketList socket_list_create(mint *sockets, mint *types, size_t length);


void socket_list_add(SocketList socketList, SOCKET socketId, SOCKET_TYPE socketType);


void socket_list_prune(SocketList socketList);


void socket_list_free(SocketList socketList);


#endif