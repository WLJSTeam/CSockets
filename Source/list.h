#ifndef LIST_H
#define LIST_H


#include "socket.h"


typedef struct SocketList_st {
    SOCKET *sockets;
    SOCKET_ROLE *roles;
    size_t capacity;
    size_t length;
} *SocketList;


/* length is the allocated element count; events contains native poll flags.
   On allocation failure, fds and length retain their previous values. */
bool fill_fds_from_socket_list(SocketList socketList, POLL_FD **fds, size_t *length, int events);


bool socket_list_add(SocketList list, SOCKET socketId, SOCKET_ROLE role);


bool socket_list_prune(SocketList list);


#endif
