#include "socket.h"


DLLEXPORT int socketCreate(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    if (Argc != 2) {
        libData->Message("socketCreate: invalid argument count");
        return LIBRARY_FUNCTION_ERROR;
    }

    int family = (int)MArgument_getInteger(Args[0]);
    mint protocol = MArgument_getInteger(Args[1]);
    int socktype;

    switch (protocol) {
        case IPPROTO_TCP:
            socktype = SOCK_STREAM;
            break;

        case IPPROTO_UDP:
            socktype = SOCK_DGRAM;
            break;

        default:
            libData->Message("socketCreate: invalid protocol");
            return LIBRARY_FUNCTION_ERROR;
    }

    SOCKET createdSocket = socket(family, socktype, (int)protocol);
    if (createdSocket == INVALID_SOCKET) {
        libData->Message(format("socketCreate: failed %d", GETSOCKETERRNO()));
        return LIBRARY_FUNCTION_ERROR;
    }

    mint socketId = (mint)createdSocket;
    MArgument_setInteger(Res, socketId);
    return LIBRARY_NO_ERROR;
}


DLLEXPORT int socketClose(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    if (Argc != 1) {
        libData->Message("socketClose: invalid argument count");
        return LIBRARY_FUNCTION_ERROR;
    }

    SOCKET socketId = (SOCKET)MArgument_getInteger(Args[0]);

    int result = 0;

    if (ISVALIDSOCKET(socketId)) {
        result = CLOSESOCKET(socketId);
    } else {
        libData->Message("socketClose: invalid socket");
        return LIBRARY_FUNCTION_ERROR;
    }

    if (result == SOCKET_ERROR) {
        libData->Message(format("socketClose: failed %d", GETSOCKETERRNO()));
        return LIBRARY_FUNCTION_ERROR;
    }

    return LIBRARY_NO_ERROR;
}


DLLEXPORT int socketBind(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    if (Argc != 3) {
        libData->Message("socketBind: invalid argument count");
        return LIBRARY_FUNCTION_ERROR;
    }

    SOCKET socketId = (SOCKET)MArgument_getInteger(Args[0]);

    char *numerichost = MArgument_getUTF8String(Args[1]);
    char *port = MArgument_getUTF8String(Args[2]);

    struct sockaddr_storage addressStorage = create_sockaddr_storage(numerichost, port);

    if (numerichost) {
        libData->UTF8String_disown(numerichost);
    }

    if (port) {
        libData->UTF8String_disown(port);
    }


    if (socketId == INVALID_SOCKET) {
        libData->Message("socketBind: invalid socket");
        return LIBRARY_FUNCTION_ERROR;
    }

    socklen_t addressSize = 0;

    switch (addressStorage.ss_family) {
        case AF_INET:
            addressSize = sizeof(struct sockaddr_in);
            break;

        case AF_INET6:
            addressSize = sizeof(struct sockaddr_in6);
            break;

        default:
            libData->Message("socketBind: unsupported address family");
            return LIBRARY_FUNCTION_ERROR;
    }

    struct sockaddr *address = (struct sockaddr *)&addressStorage;
    int result = bind(socketId, address, addressSize);

    if (result == SOCKET_ERROR) {
        libData->Message(format("socketBind: failed %d", GETSOCKETERRNO()));
        return LIBRARY_FUNCTION_ERROR;
    }

    return LIBRARY_NO_ERROR;
}


DLLEXPORT int socketSetOpt(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    if (Argc != 4) {
        libData->Message("socketSetOpt: invalid argument count");
        return LIBRARY_FUNCTION_ERROR;
    }

    SOCKET socketId = (SOCKET)MArgument_getInteger(Args[0]);
    int level = (int)MArgument_getInteger(Args[1]);
    int optname = (int)MArgument_getInteger(Args[2]);
    int optval = (int)MArgument_getInteger(Args[3]);

    int result = setsockopt(socketId, level, optname, (const char *)&optval, sizeof(optval));

    if (result == SOCKET_ERROR) {
        libData->Message(format("socketSetOpt: failed %d", GETSOCKETERRNO()));
        return LIBRARY_FUNCTION_ERROR;
    }

    return LIBRARY_NO_ERROR;
}


DLLEXPORT int socketGetOpt(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    if (Argc != 3) {
        libData->Message("socketGetOpt: invalid argument count");
        return LIBRARY_FUNCTION_ERROR;
    }

    SOCKET socketId = (SOCKET)MArgument_getInteger(Args[0]);
    int level = (int)MArgument_getInteger(Args[1]);
    int optname = (int)MArgument_getInteger(Args[2]);

    int optval = 0;
    socklen_t optlen = sizeof(optval);

    int result = getsockopt(socketId, level, optname, (char *)&optval, &optlen);

    if (result == SOCKET_ERROR) {
        libData->Message(format("socketGetOpt: failed %d", GETSOCKETERRNO()));
        return LIBRARY_FUNCTION_ERROR;
    }

    MArgument_setInteger(Res, optval);
    return LIBRARY_NO_ERROR;
}


DLLEXPORT int socketSetBlockingMode(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    if (Argc != 1) {
        libData->Message("socketSetBlockingMode: failed: invalid argument count");
        return LIBRARY_FUNCTION_ERROR;
    }

    SOCKET socketId = (SOCKET)MArgument_getInteger(Args[0]);

    bool valid = ISVALIDSOCKET(socketId);

    if (!valid) {
        libData->Message("socketSetBlockingMode: invalid socket");
        return LIBRARY_FUNCTION_ERROR;
    }

    int status = set_blocking_mode(socketId);

    if (status == SOCKET_ERROR) {
        libData->Message("socketSetBlockingMode: failed to set blocking mode");
        return LIBRARY_FUNCTION_ERROR;
    }

    return LIBRARY_NO_ERROR;
}


DLLEXPORT int socketSetNonBlockingMode(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    if (Argc != 1) {
        libData->Message("socketSetNonBlockingMode: invalid argument count");
        return LIBRARY_FUNCTION_ERROR;
    }

    SOCKET socketId = (SOCKET)MArgument_getInteger(Args[0]);

    bool valid = ISVALIDSOCKET(socketId);

    if (!valid) {
        libData->Message("socketSetNonBlockingMode: invalid socket");
        return LIBRARY_FUNCTION_ERROR;
    }

    int status = set_nonblocking_mode(socketId);

    if (status == SOCKET_ERROR) {
        libData->Message("socketSetNonBlockingMode: failed to set nonblocking mode");
        return LIBRARY_FUNCTION_ERROR;
    }

    return LIBRARY_NO_ERROR;
}


DLLEXPORT int socketGetAddresses(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    if (Argc != 2) {
        libData->Message("socketGetAddresses: invalid argument count");
        return LIBRARY_FUNCTION_ERROR;
    }

    SOCKET socketId = (SOCKET)MArgument_getInteger(Args[0]);
    mint role = MArgument_getInteger(Args[1]);

    struct sockaddr_storage addressStorage[2] = {0};
    int socketType = 0;
    socklen_t typeLength = sizeof(socketType);
    int status = getsockopt(socketId, SOL_SOCKET, SO_TYPE, (char *)&socketType, &typeLength);

    if (status == SOCKET_ERROR) {
        libData->Message("socketGetAddresses: failed to get socket type");
        return LIBRARY_FUNCTION_ERROR;
    }

    const char *scheme = socketType == SOCK_DGRAM ? "udp://" : "tcp://";

    switch (role) {
        case SOCKET_ROLE_TCP_UNSPEC:
        case SOCKET_ROLE_UDP_UNSPEC:
            break;

        case SOCKET_ROLE_TCP_BOUND:
        case SOCKET_ROLE_UDP_BOUND:
            {
                socklen_t length = sizeof(addressStorage[0]);
                status = getsockname(socketId, (struct sockaddr *)&addressStorage[0], &length);

                if (status == SOCKET_ERROR) {
                    ZeroMemory(&addressStorage[0], sizeof(addressStorage[0]));
                }
            }
            break;

        case SOCKET_ROLE_TCP_ACCEPTED:
        case SOCKET_ROLE_TCP_CONNECTED:
        case SOCKET_ROLE_UDP_CONNECTED:
            {
                socklen_t length = sizeof(addressStorage[0]);
                status = getsockname(socketId, (struct sockaddr *)&addressStorage[0], &length);

                if (status == SOCKET_ERROR) {
                    ZeroMemory(&addressStorage[0], sizeof(addressStorage[0]));
                }

                length = sizeof(addressStorage[1]);
                status = getpeername(socketId, (struct sockaddr *)&addressStorage[1], &length);

                if (status == SOCKET_ERROR) {
                    ZeroMemory(&addressStorage[1], sizeof(addressStorage[1]));
                }
            }
            break;

        default:
            libData->Message("socketGetAddresses: invalid role");
            return LIBRARY_FUNCTION_ERROR;
    }

    DataStore addresses = libData->ioLibraryFunctions->createDataStore();

    if (!addresses) {
        libData->Message("socketGetAddresses: failed to allocate address store");
        return LIBRARY_MEMORY_ERROR;
    }

    for (int i = 0; i < 2; i++) {
        char *endpoint = sockaddr_storage_to_string(addressStorage[i]);

        if (!endpoint) {
            continue;
        }

        char address[INET6_ADDRSTRLEN + 64];
        int length = snprintf(address, sizeof(address), "%s%s", scheme, endpoint);
        bool invalidLength = length < 0 || (size_t)length >= sizeof(address);

        if (invalidLength) {
            libData->ioLibraryFunctions->deleteDataStore(addresses);
            libData->Message("socketGetAddresses: failed to format address");
            return LIBRARY_FUNCTION_ERROR;
        }

        libData->ioLibraryFunctions->DataStore_addString(addresses, address);
    }

    MArgument_setDataStore(Res, addresses);
    return LIBRARY_NO_ERROR;
}


DLLEXPORT int socketListen(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    if (Argc != 2) {
        libData->Message("socketListen: invalid argument count");
        return LIBRARY_FUNCTION_ERROR;
    }

    SOCKET socketId = (SOCKET)MArgument_getInteger(Args[0]);
    mint backlog = MArgument_getInteger(Args[1]);

    if (!ISVALIDSOCKET(socketId)) {
        libData->Message("socketListen: invalid socket");
        return LIBRARY_FUNCTION_ERROR;
    }

    int result = listen(socketId, (int)backlog);
    if (result == SOCKET_ERROR) {
        libData->Message(format("socketListen: failed %d", GETSOCKETERRNO()));
        return LIBRARY_FUNCTION_ERROR;
    }

    return LIBRARY_NO_ERROR;
}


DLLEXPORT int socketConnect(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    if (Argc != 3) {
        libData->Message("socketConnect: invalid argument count");
        return LIBRARY_FUNCTION_ERROR;
    }

    SOCKET socketId = (SOCKET)MArgument_getInteger(Args[0]);

    char *numerichost = MArgument_getUTF8String(Args[1]);
    char *port = MArgument_getUTF8String(Args[2]);

    struct sockaddr_storage addressStorage = create_sockaddr_storage(numerichost, port);

    if (numerichost) {
        libData->UTF8String_disown(numerichost);
    }

    if (port) {
        libData->UTF8String_disown(port);
    }

    socklen_t addressSize = 0;

    switch (addressStorage.ss_family) {
        case AF_INET:
            addressSize = sizeof(struct sockaddr_in);
            break;

        case AF_INET6:
            addressSize = sizeof(struct sockaddr_in6);
            break;

        default:
            libData->Message("socketConnect: unsupported address family");
            return LIBRARY_FUNCTION_ERROR;
    }

    int result = connect(socketId, (struct sockaddr *)&addressStorage, addressSize);

    if (result == SOCKET_ERROR) {
        int err = GETSOCKETERRNO();
        if (!is_connect_pending_err(err)) {
            libData->Message(format("socketConnect: failed %d", err));
            return LIBRARY_FUNCTION_ERROR;
        }
    }

    return LIBRARY_NO_ERROR;
}


DLLEXPORT int socketAccept(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    if (Argc != 1) {
        libData->Message("socketAccept: invalid argument count");
        return LIBRARY_FUNCTION_ERROR;
    }

    SOCKET listenSocketId = (SOCKET)MArgument_getInteger(Args[0]);

    SOCKET acceptedSocket = accept(listenSocketId, NULL, NULL);

    if (acceptedSocket == INVALID_SOCKET) {
        libData->Message("socketAccept: failed to accept a connection");
        return LIBRARY_FUNCTION_ERROR;
    }

    mint acceptedSocketId = (mint)acceptedSocket;
    MArgument_setInteger(Res, acceptedSocketId);
    return LIBRARY_NO_ERROR;
}


DLLEXPORT int socketRecv(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    if (Argc != 2) {
        libData->Message("socketRecv: invalid argument count");
        return LIBRARY_FUNCTION_ERROR;
    }

    SOCKET socketId = (SOCKET)MArgument_getInteger(Args[0]);

    MNumericArray buffer = MArgument_getMNumericArray(Args[1]);
    size_t bufferSize = 0;
    BYTE *bufferData = ByteFromMNumericArray(libData, buffer, &bufferSize);
    numericarray_data_t arrayType = libData->numericarrayLibraryFunctions->MNumericArray_getType(buffer);
    mint arrayRank = libData->numericarrayLibraryFunctions->MNumericArray_getRank(buffer);

    if (arrayType != MNumericArray_Type_UBit8 || arrayRank != 1) {
        libData->numericarrayLibraryFunctions->MNumericArray_disown(buffer);
        libData->Message("socketRecv: expected a rank-one byte array");
        return LIBRARY_TYPE_ERROR;
    }

    if (bufferSize > INT_MAX) {
        libData->Message("socketRecv: buffer too large");
        libData->numericarrayLibraryFunctions->MNumericArray_disown(buffer);
        return LIBRARY_FUNCTION_ERROR;
    }

    int result = recv(socketId, (char *)bufferData, (int)bufferSize, 0);

    if (result >= 0) {
        MNumericArray receivedData = MNumericArrayFromByte(libData, bufferData, (size_t)result);
        libData->numericarrayLibraryFunctions->MNumericArray_disown(buffer);

        if (!receivedData) {
            libData->Message("socketRecv: failed to allocate result array");
            return LIBRARY_MEMORY_ERROR;
        }

        MArgument_setMNumericArray(Res, receivedData);
        return LIBRARY_NO_ERROR;
    }

    libData->Message(format("socketRecv: failed %d", GETSOCKETERRNO()));
    libData->numericarrayLibraryFunctions->MNumericArray_disown(buffer);
    return LIBRARY_FUNCTION_ERROR;
}


DLLEXPORT int socketRecvFrom(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    if (Argc != 2) {
        libData->Message("socketRecvFrom: invalid argument count");
        return LIBRARY_FUNCTION_ERROR;
    }

    SOCKET socketId = (SOCKET)MArgument_getInteger(Args[0]);

    MNumericArray buffer = MArgument_getMNumericArray(Args[1]);
    size_t bufferSize = 0;
    BYTE *bufferData = ByteFromMNumericArray(libData, buffer, &bufferSize);
    numericarray_data_t arrayType = libData->numericarrayLibraryFunctions->MNumericArray_getType(buffer);
    mint arrayRank = libData->numericarrayLibraryFunctions->MNumericArray_getRank(buffer);

    if (arrayType != MNumericArray_Type_UBit8 || arrayRank != 1) {
        libData->numericarrayLibraryFunctions->MNumericArray_disown(buffer);
        libData->Message("socketRecvFrom: expected a rank-one byte array");
        return LIBRARY_TYPE_ERROR;
    }

    if (bufferSize > INT_MAX) {
        libData->Message("socketRecvFrom: buffer too large");
        libData->numericarrayLibraryFunctions->MNumericArray_disown(buffer);
        return LIBRARY_FUNCTION_ERROR;
    }

    struct sockaddr_storage addressStorage;
    ZeroMemory(&addressStorage, sizeof(addressStorage));

    struct sockaddr *address = (struct sockaddr *)&addressStorage;
    socklen_t addressLength = sizeof(addressStorage);

    int result = recvfrom(socketId, (char *)bufferData, (int)bufferSize, 0, address, &addressLength);

    if (result < 0) {
        libData->Message(format("socketRecvFrom: failed %d", GETSOCKETERRNO()));
        libData->numericarrayLibraryFunctions->MNumericArray_disown(buffer);
        return LIBRARY_FUNCTION_ERROR;
    }

    char *receivedAddress = sockaddr_storage_to_string(addressStorage);

    if (!receivedAddress) {
        libData->Message("socketRecvFrom: failed to format sender address");
        libData->numericarrayLibraryFunctions->MNumericArray_disown(buffer);
        return LIBRARY_FUNCTION_ERROR;
    }

    DataStore dataStore = libData->ioLibraryFunctions->createDataStore();

    if (!dataStore) {
        libData->Message("socketRecvFrom: failed to allocate data store");
        libData->numericarrayLibraryFunctions->MNumericArray_disown(buffer);
        return LIBRARY_MEMORY_ERROR;
    }

    libData->ioLibraryFunctions->DataStore_addString(dataStore, receivedAddress);

    if (result > 0) {
        MNumericArray receivedData = MNumericArrayFromByte(libData, bufferData, (size_t)result);

        if (!receivedData) {
            libData->numericarrayLibraryFunctions->MNumericArray_disown(buffer);
            libData->ioLibraryFunctions->deleteDataStore(dataStore);
            libData->Message("socketRecvFrom: failed to allocate result array");
            return LIBRARY_MEMORY_ERROR;
        }

        libData->ioLibraryFunctions->DataStore_addMNumericArray(dataStore, receivedData);
    }

    MArgument_setDataStore(Res, dataStore);
    libData->numericarrayLibraryFunctions->MNumericArray_disown(buffer);

    return LIBRARY_NO_ERROR;
}


static int receiveArrayInto(WolframLibraryData libData, SOCKET socketId, MNumericArray buffer,
    struct sockaddr_storage *addressStorage, int *bytesRead)
{
    size_t capacity = 0;
    BYTE *data = ByteFromMNumericArray(libData, buffer, &capacity);

    if (!data || capacity == 0 || capacity > INT_MAX) {
        libData->numericarrayLibraryFunctions->MNumericArray_disown(buffer);
        libData->Message("socket receive into: invalid buffer");
        return LIBRARY_FUNCTION_ERROR;
    }

    int received;

    if (addressStorage) {
        socklen_t addressLength = sizeof(*addressStorage);
        received = recvfrom(socketId, (char *)data, (int)capacity, 0,
            (struct sockaddr *)addressStorage, &addressLength);
    } else {
        received = recv(socketId, (char *)data, (int)capacity, 0);
    }

    if (received == SOCKET_ERROR) {
        int error = GETSOCKETERRNO();
        libData->numericarrayLibraryFunctions->MNumericArray_disown(buffer);
        libData->Message(format("socket receive into: failed %d", error));
        return LIBRARY_FUNCTION_ERROR;
    }

    libData->numericarrayLibraryFunctions->MNumericArray_disown(buffer);
    *bytesRead = received;
    return LIBRARY_NO_ERROR;
}


DLLEXPORT int socketRecvInto(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    if (Argc != 2) {
        libData->Message("socketRecvInto: invalid argument count");
        return LIBRARY_FUNCTION_ERROR;
    }

    SOCKET socketId = (SOCKET)MArgument_getInteger(Args[0]);
    MNumericArray buffer = MArgument_getMNumericArray(Args[1]);

    int bytesRead = 0;
    int status = receiveArrayInto(libData, socketId, buffer, NULL, &bytesRead);

    if (status != LIBRARY_NO_ERROR) {
        return status;
    }

    MArgument_setInteger(Res, bytesRead);
    return LIBRARY_NO_ERROR;
}


DLLEXPORT int socketRecvFromInto(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    if (Argc != 2) {
        libData->Message("socketRecvFromInto: invalid argument count");
        return LIBRARY_FUNCTION_ERROR;
    }

    SOCKET socketId = (SOCKET)MArgument_getInteger(Args[0]);
    MNumericArray buffer = MArgument_getMNumericArray(Args[1]);

    struct sockaddr_storage addressStorage = {0};
    int bytesRead = 0;
    int status = receiveArrayInto(libData, socketId, buffer, &addressStorage, &bytesRead);

    if (status != LIBRARY_NO_ERROR) {
        return status;
    }

    char *senderAddress = sockaddr_storage_to_string(addressStorage);

    if (!senderAddress) {
        libData->Message("socketRecvFromInto: failed to format sender address");
        return LIBRARY_FUNCTION_ERROR;
    }

    DataStore result = libData->ioLibraryFunctions->createDataStore();

    if (!result) {
        libData->Message("socketRecvFromInto: failed to allocate data store");
        return LIBRARY_MEMORY_ERROR;
    }

    libData->ioLibraryFunctions->DataStore_addInteger(result, bytesRead);
    libData->ioLibraryFunctions->DataStore_addString(result, senderAddress);
    MArgument_setDataStore(Res, result);
    return LIBRARY_NO_ERROR;
}


static int sendSocketBytes(WolframLibraryData libData, SOCKET socketId, const char *buffer,
    int requested, int *bytesSent)
{
    int sentLength = send(socketId, buffer, requested, 0);

    if (sentLength == SOCKET_ERROR) {
        int error = GETSOCKETERRNO();
        libData->Message(format("socketSend: failed %d", error));
        return LIBRARY_FUNCTION_ERROR;
    }

    if (sentLength == 0 && requested > 0) {
        libData->Message("socketSend: no progress");
        return LIBRARY_FUNCTION_ERROR;
    }

    if (sentLength < requested) {
        int socketType;
        socklen_t typeLength = sizeof(socketType);
        int status = getsockopt(socketId, SOL_SOCKET, SO_TYPE, (char *)&socketType, &typeLength);

        if (status == SOCKET_ERROR) {
            int error = GETSOCKETERRNO();
            libData->Message(format("socketSend: SO_TYPE failed %d after %d bytes", error, sentLength));
            return LIBRARY_FUNCTION_ERROR;
        }

        if (socketType != SOCK_STREAM) {
            libData->Message("socketSend: short datagram");
            return LIBRARY_FUNCTION_ERROR;
        }

        while (sentLength < requested) {
            mint aborted = libData->AbortQ();

            if (aborted) {
                libData->Message(format("socketSend: aborted after %d bytes", sentLength));
                return LIBRARY_FUNCTION_ERROR;
            }

            int remaining = requested - sentLength;
            int sent = send(socketId, buffer + sentLength, remaining, 0);

            if (sent == SOCKET_ERROR) {
                int error = GETSOCKETERRNO();
                libData->Message(format("socketSend: failed %d after %d bytes", error, sentLength));
                return LIBRARY_FUNCTION_ERROR;
            }

            if (sent == 0) {
                libData->Message(format("socketSend: no progress after %d bytes", sentLength));
                return LIBRARY_FUNCTION_ERROR;
            }

            sentLength += sent;
        }
    }

    *bytesSent = sentLength;
    return LIBRARY_NO_ERROR;
}


static int sendSocketDatagram(WolframLibraryData libData, SOCKET socketId, const char *buffer,
    int requested, const struct sockaddr_storage *addressStorage, int *bytesSent)
{
    socklen_t addressLength;

    switch (addressStorage->ss_family) {
        case AF_INET:
            addressLength = sizeof(struct sockaddr_in);
            break;

        case AF_INET6:
            addressLength = sizeof(struct sockaddr_in6);
            break;

        default:
            libData->Message("socketSendTo: unsupported address family");
            return LIBRARY_FUNCTION_ERROR;
    }

    const struct sockaddr *address = (const struct sockaddr *)addressStorage;
    int sentLength = sendto(socketId, buffer, requested, 0, address, addressLength);

    if (sentLength == SOCKET_ERROR) {
        int error = GETSOCKETERRNO();
        libData->Message(format("socketSendTo: failed %d", error));
        return LIBRARY_FUNCTION_ERROR;
    }

    if (sentLength != requested) {
        libData->Message("socketSendTo: short datagram");
        return LIBRARY_FUNCTION_ERROR;
    }

    *bytesSent = sentLength;
    return LIBRARY_NO_ERROR;
}


static int sendArray(WolframLibraryData libData, SOCKET socketId, MNumericArray bytes,
    mint offset, mint length, bool wholeArray, const struct sockaddr_storage *address, int *bytesSent)
{
    size_t capacity = 0;
    BYTE *data = ByteFromMNumericArray(libData, bytes, &capacity);
    numericarray_data_t arrayType = libData->numericarrayLibraryFunctions->MNumericArray_getType(bytes);
    mint arrayRank = libData->numericarrayLibraryFunctions->MNumericArray_getRank(bytes);

    if (arrayType != MNumericArray_Type_UBit8 || arrayRank != 1) {
        libData->numericarrayLibraryFunctions->MNumericArray_disown(bytes);
        libData->Message("socket send: expected a rank-one byte array");
        return LIBRARY_TYPE_ERROR;
    }

    size_t requested = wholeArray ? capacity : (size_t)length;

    if (offset < 0 || length < 0 || (uintmax_t)offset > capacity ||
        (!wholeArray && (uintmax_t)length > capacity - (size_t)offset) || requested > INT_MAX) {
        libData->numericarrayLibraryFunctions->MNumericArray_disown(bytes);
        libData->Message("socket send: invalid offset or length");
        return LIBRARY_FUNCTION_ERROR;
    }

    const char *buffer = requested > 0 ? (const char *)data + (size_t)offset : "";
    int status;

    if (address) {
        status = sendSocketDatagram(libData, socketId, buffer, (int)requested, address, bytesSent);
    } else {
        status = sendSocketBytes(libData, socketId, buffer, (int)requested, bytesSent);
    }

    libData->numericarrayLibraryFunctions->MNumericArray_disown(bytes);
    return status;
}


static struct sockaddr_storage takeSendAddress(WolframLibraryData libData, char *host, char *port)
{
    struct sockaddr_storage address = create_sockaddr_storage(host, port);

    if (host) {
        libData->UTF8String_disown(host);
    }

    if (port) {
        libData->UTF8String_disown(port);
    }

    return address;
}


DLLEXPORT int socketSend(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    if (Argc != 2) {
        libData->Message("socketSend: invalid argument count");
        return LIBRARY_FUNCTION_ERROR;
    }

    SOCKET socketId = (SOCKET)MArgument_getInteger(Args[0]);
    MNumericArray bytes = MArgument_getMNumericArray(Args[1]);

    int sentLength = 0;
    int status = sendArray(libData, socketId, bytes, 0, 0, true, NULL, &sentLength);

    if (status != LIBRARY_NO_ERROR) {
        return status;
    }

    MArgument_setInteger(Res, sentLength);
    return LIBRARY_NO_ERROR;
}


DLLEXPORT int socketSendRange(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    if (Argc != 4) {
        libData->Message("socketSendRange: invalid argument count");
        return LIBRARY_FUNCTION_ERROR;
    }

    SOCKET socketId = (SOCKET)MArgument_getInteger(Args[0]);
    MNumericArray bytes = MArgument_getMNumericArray(Args[1]);
    mint offset = MArgument_getInteger(Args[2]);
    mint length = MArgument_getInteger(Args[3]);

    int sentLength = 0;
    int status = sendArray(libData, socketId, bytes, offset, length, false, NULL, &sentLength);

    if (status != LIBRARY_NO_ERROR) {
        return status;
    }

    MArgument_setInteger(Res, sentLength);
    return LIBRARY_NO_ERROR;
}


DLLEXPORT int socketSendTo(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    if (Argc != 4) {
        libData->Message("socketSendTo: invalid argument count");
        return LIBRARY_FUNCTION_ERROR;
    }

    SOCKET socketId = (SOCKET)MArgument_getInteger(Args[0]);
    char *numerichost = MArgument_getUTF8String(Args[1]);
    char *port = MArgument_getUTF8String(Args[2]);
    MNumericArray data = MArgument_getMNumericArray(Args[3]);

    struct sockaddr_storage address = takeSendAddress(libData, numerichost, port);
    int sentLength = 0;
    int status = sendArray(libData, socketId, data, 0, 0, true, &address, &sentLength);

    if (status != LIBRARY_NO_ERROR) {
        return status;
    }

    MArgument_setInteger(Res, sentLength);
    return LIBRARY_NO_ERROR;
}


DLLEXPORT int socketSendToRange(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    if (Argc != 6) {
        libData->Message("socketSendToRange: invalid argument count");
        return LIBRARY_FUNCTION_ERROR;
    }

    SOCKET socketId = (SOCKET)MArgument_getInteger(Args[0]);
    char *numerichost = MArgument_getUTF8String(Args[1]);
    char *port = MArgument_getUTF8String(Args[2]);
    MNumericArray data = MArgument_getMNumericArray(Args[3]);
    mint offset = MArgument_getInteger(Args[4]);
    mint length = MArgument_getInteger(Args[5]);

    struct sockaddr_storage address = takeSendAddress(libData, numerichost, port);
    int sentLength = 0;
    int status = sendArray(libData, socketId, data, offset, length, false, &address, &sentLength);

    if (status != LIBRARY_NO_ERROR) {
        return status;
    }

    MArgument_setInteger(Res, sentLength);
    return LIBRARY_NO_ERROR;
}


DLLEXPORT int socketsCheck(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    if (Argc != 1) {
        libData->Message("socketsCheck: invalid argument count");
        return LIBRARY_FUNCTION_ERROR;
    }

    MTensor sockets = MArgument_getMTensor(Args[0]);

    size_t length = 0;
    SOCKET *data = SocketFromMTensor(libData, sockets, &length);

    if (!data) {
        libData->Message("socketsCheck: invalid socket vector or allocation failed");
        return LIBRARY_FUNCTION_ERROR;
    }

    size_t count = 0;

    for (size_t i = 0; i < length; i++) {
        bool valid = ISVALIDSOCKET(data[i]);

        if (valid) {
            data[count] = data[i];
            count++;
        }
    }

    MTensor validSockets = MTensorFromSocket(libData, data, count);
    free(data);

    if (!validSockets) {
        libData->Message("socketsCheck: failed to allocate result tensor");
        return LIBRARY_MEMORY_ERROR;
    }

    MArgument_setMTensor(Res, validSockets);
    return LIBRARY_NO_ERROR;
}


DLLEXPORT int socketConnectedQ(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    if (Argc != 1) {
        libData->Message("socketConnectedQ: invalid argument count");
        return LIBRARY_FUNCTION_ERROR;
    }

    SOCKET socketId = (SOCKET)MArgument_getInteger(Args[0]);
    struct sockaddr_storage peer;
    socklen_t length = sizeof(peer);

    MArgument_setBoolean(Res, getpeername(socketId, (struct sockaddr *)&peer, &length) == 0);
    return LIBRARY_NO_ERROR;
}


DLLEXPORT int socketConnectionAliveQ(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    if (Argc != 1) {
        libData->Message("socketConnectionAliveQ: invalid argument count");
        return LIBRARY_FUNCTION_ERROR;
    }

    SOCKET socketId = (SOCKET)MArgument_getInteger(Args[0]);

    if (!ISVALIDSOCKET(socketId)) {
        MArgument_setBoolean(Res, False);
        return LIBRARY_NO_ERROR;
    }

    char dummy;
    int ret = recv(socketId, &dummy, 1, MSG_PEEK);
    int err = GETSOCKETERRNO();

    if (ret > 0) {
        MArgument_setBoolean(Res, True);
        return LIBRARY_NO_ERROR;
    }

    if (ret == 0) {
        MArgument_setBoolean(Res, False);
        return LIBRARY_NO_ERROR;
    }

    if (is_would_block_err(err)) {
        MArgument_setBoolean(Res, True);
        return LIBRARY_NO_ERROR;
    }

    MArgument_setBoolean(Res, False);
    return LIBRARY_NO_ERROR;
}


DLLEXPORT int socketValidQ(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    if (Argc != 1) {
        libData->Message("socketValidQ: invalid argument count");
        return LIBRARY_FUNCTION_ERROR;
    }

    SOCKET socketId = (SOCKET)MArgument_getInteger(Args[0]);

    if (!ISVALIDSOCKET(socketId)) {
        MArgument_setBoolean(Res, False);
        return LIBRARY_NO_ERROR;
    }

    int type;
    socklen_t length = sizeof(type);

    int result = getsockopt(socketId, SOL_SOCKET, SO_TYPE, (char *)&type, &length);
    mbool validState = result == 0;

    MArgument_setBoolean(Res, validState);
    return LIBRARY_NO_ERROR;
}


DLLEXPORT int socketsPoll(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    if (Argc != 3) {
        libData->Message("socketsPoll: invalid argument count");
        return LIBRARY_FUNCTION_ERROR;
    }

    MTensor socketsTensor = MArgument_getMTensor(Args[0]);
    mint timeout = MArgument_getInteger(Args[1]);
    mint eventsMask = MArgument_getInteger(Args[2]);

    if (libData->MTensor_getRank(socketsTensor) != 1) {
        libData->Message("socketsPoll: expected a list of socket descriptors");
        return LIBRARY_FUNCTION_ERROR;
    }

    mint length = libData->MTensor_getFlattenedLength(socketsTensor);
    mint *socketArray = libData->MTensor_getIntegerData(socketsTensor);

    if (length == 0) {
        MTensor emptyTensor;
        mint dims[2] = {0, 2};

        if (libData->MTensor_new(MType_Integer, 2, dims, &emptyTensor)) {
            libData->Message("socketsPoll: allocation failed for empty result tensor");
            return LIBRARY_MEMORY_ERROR;
        }

        MArgument_setMTensor(Res, emptyTensor);
        return LIBRARY_NO_ERROR;
    }

    if ((size_t)length > SIZE_MAX / sizeof(POLL_FD)) {
        libData->Message("socketsPoll: allocation would overflow pollfds array");
        return LIBRARY_MEMORY_ERROR;
    }

    POLL_FD *fds = malloc(sizeof(POLL_FD) * (size_t)length);

    if (!fds) {
        libData->Message("socketsPoll: allocation failed for pollfds array");
        return LIBRARY_MEMORY_ERROR;
    }

    int nativeEvents = convert_wl_to_native_events(eventsMask);

    for (mint i = 0; i < length; i++) {
        fds[i].fd = (SOCKET)socketArray[i];
        fds[i].events = nativeEvents;
        fds[i].revents = 0;
    }

    int result = sockets_poll_abort(libData, fds, length, timeout, 5000);

    if (result < 0) {
        libData->Message(format("socketsPoll: failed %d", GETSOCKETERRNO()));
        free(fds);
        return LIBRARY_FUNCTION_ERROR;
    }

    mint dims[2] = {result, 2};
    MTensor resultTensor;

    if (libData->MTensor_new(MType_Integer, 2, dims, &resultTensor)) {
        free(fds);
        libData->Message("socketsPoll: allocation failed for result tensor");
        return LIBRARY_MEMORY_ERROR;
    }

    mint *resultData = libData->MTensor_getIntegerData(resultTensor);

    mint idx = 0;

    for (mint i = 0; i < length && idx < result; i++) {
        if (fds[i].revents != 0) {
            resultData[2 * idx] = socketArray[i];
            resultData[2 * idx + 1] = convert_native_to_wl_events(fds[i].revents);
            idx++;
        }
    }

    free(fds);
    MArgument_setMTensor(Res, resultTensor);
    return LIBRARY_NO_ERROR;
}
