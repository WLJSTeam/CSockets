#include "address.h"


DLLEXPORT int socketAddressInfoCreate(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    char *host = MArgument_getUTF8String(Args[0]);        // remote host (can be NULL)
    char *port = MArgument_getUTF8String(Args[1]);        // port as string
    int ai_family = (int)MArgument_getInteger(Args[2]);   // AF_UNSPEC, AF_INET, AF_INET6
    int ai_socktype = (int)MArgument_getInteger(Args[3]); // SOCK_STREAM, SOCK_DGRAM
    int ai_protocol = (int)MArgument_getInteger(Args[4]); // 0, IPPROTO_TCP, IPPROTO_UDP
    char *localIP = MArgument_getUTF8String(Args[5]);     // local IP for binding

    int result;
    struct addrinfo *address = NULL;
    struct addrinfo hints;

    ZeroMemory(&hints, sizeof(hints));
    hints.ai_family = ai_family;
    hints.ai_socktype = ai_socktype;
    hints.ai_protocol = ai_protocol;

    char *bindHost = NULL;

    if (localIP != NULL && strlen(localIP) > 0) {
        hints.ai_flags = AI_PASSIVE;
        if (strcmp(localIP, "0.0.0.0") != 0 && strcmp(localIP, "::") != 0) {
            bindHost = localIP;  // Bind to specific interface (e.g., "192.168.1.100")
        }
        // If localIP == "0.0.0.0" or "::", bindHost stays NULL -> INADDR_ANY (all interfaces)
    }
    else if (host == NULL || strlen(host) == 0) {
        hints.ai_flags = AI_PASSIVE;
        bindHost = NULL;  // INADDR_ANY
    }
    else {
        bindHost = host;
    }

    result = getaddrinfo(bindHost, port, &hints, &address);

    if (host) libData->UTF8String_disown(host);
    if (port) libData->UTF8String_disown(port);
    if (localIP) libData->UTF8String_disown(localIP);

    if (result != 0) {
        return LIBRARY_FUNCTION_ERROR;
    }

    mint addressPtr = (mint)(uintptr_t)address;
    MArgument_setInteger(Res, addressPtr);
    return LIBRARY_NO_ERROR;
}


DLLEXPORT int socketAddressInfoRemove(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    uintptr_t addressPtr = (uintptr_t)MArgument_getInteger(Args[0]); // address pointer as integer
    struct addrinfo *address = (struct addrinfo*)addressPtr;

    if (address == NULL) {
        return LIBRARY_FUNCTION_ERROR;
    }

    freeaddrinfo(address);
    return LIBRARY_NO_ERROR;
}