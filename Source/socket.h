#ifndef SOCKET_H
#define SOCKET_H


#include "common.h"


typedef enum SocketProtocol {
    SOCKET_PROTOCOL_AUTO = 0,
    SOCKET_PROTOCOL_TCP = IPPROTO_TCP,
    SOCKET_PROTOCOL_UDP = IPPROTO_UDP
} SocketProtocol;


typedef enum SocketType {
    SOCKET_TYPE_STREAM = SOCK_STREAM,
    SOCKET_TYPE_DGRAM = SOCK_DGRAM
} SocketType;


typedef enum SocketRole {
    SOCKET_ROLE_INTERRUPTER = 0,
    SOCKET_ROLE_LISTENER = 1,
    SOCKET_ROLE_CONNECTED = 2,
    SOCKET_ROLE_ACCEPTED = 3
} SocketRole;


typedef enum SocketState {
    SOCKET_STATE_CLOSED = 0,
    SOCKET_STATE_ALIVE = 1
} SocketState;


typedef enum SocketMode {
    SOCKET_MODE_BLOCKING = 0,
    SOCKET_MODE_NONBLOCKING = 1
} SocketMode;


typedef struct SocketObject {
    mint socket;
    SocketProtocol protocol;
    SocketType type;
    SocketRole role;
    SocketState state;
    SocketMode mode;
} SocketObject;


SocketObject MArgument_getSocketObject(WolframLibraryData libData, MArgument arg);


void MArgument_setSocketObject(WolframLibraryData libData, MArgument res, SocketObject socketObject);


void MArgument_updateSocketObject(WolframLibraryData libData, MArgument arg, SocketObject socketObject);


BYTE *MArgument_getByteArray(WolframLibraryData libData, MArgument arg);


void MArgument_setByteArray(WolframLibraryData libData, MArgument res, BYTE *data, mint length);


#endif