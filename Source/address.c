#include "address.h"

/* socketAddressInfoCreate["host", "port", family, socktype, protocol, localIP] -> addressInfoPtr */
/*
   Creates addrinfo structure for socket operations.

   Parameters:
   - host: remote host (for client) or NULL/empty (for server)
   - port: port number as string
   - family: AF_UNSPEC (0), AF_INET (2), AF_INET6 (23/10)
   - socktype: SOCK_STREAM (1), SOCK_DGRAM (2), SOCK_RAW (3)
   - protocol: 0 (auto), IPPROTO_TCP (6), IPPROTO_UDP (17), etc.
   - localIP: local IP address for binding (NULL, "0.0.0.0", or specific IP like "192.168.1.100")

   Changes made:
   1. Added 6th parameter 'localIP' to allow binding to specific network interface
   2. Added AI_PASSIVE flag for server sockets and when localIP is specified
   3. Proper handling of NULL/empty host for server mode
   4. Support for binding to specific interface via localIP parameter
*/
DLLEXPORT int socketAddressInfoCreate(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res) {
    // Get parameters from Wolfram
    char *host = MArgument_getUTF8String(Args[0]);     // remote host (can be NULL)
    char *port = MArgument_getUTF8String(Args[1]);     // port as string
    int ai_family = (int)MArgument_getInteger(Args[2]);    // AF_UNSPEC, AF_INET, AF_INET6
    int ai_socktype = (int)MArgument_getInteger(Args[3]);  // SOCK_STREAM, SOCK_DGRAM
    int ai_protocol = (int)MArgument_getInteger(Args[4]);  // 0, IPPROTO_TCP, IPPROTO_UDP
    char *localIP = MArgument_getUTF8String(Args[5]);      // NEW: local IP for binding

    int result;
    struct addrinfo *address = NULL;
    struct addrinfo hints;

    // Initialize hints structure with zeros
    ZeroMemory(&hints, sizeof(hints));
    hints.ai_family = ai_family;
    hints.ai_socktype = ai_socktype;
    hints.ai_protocol = ai_protocol;

    // Determine the host string to use for getaddrinfo
    char *bindHost = NULL;

    // NEW: Handle localIP parameter for binding to specific interface
    if (localIP != NULL && strlen(localIP) > 0) {
        // When localIP is specified, we're creating an address for binding
        hints.ai_flags = AI_PASSIVE;

        // If localIP is NOT "0.0.0.0" or "::", use it for binding to specific interface
        if (strcmp(localIP, "0.0.0.0") != 0 && strcmp(localIP, "::") != 0) {
            bindHost = localIP;  // Bind to specific interface (e.g., "192.168.1.100")
        }
        // If localIP == "0.0.0.0" or "::", bindHost stays NULL -> INADDR_ANY (all interfaces)
    }
    // NEW: Handle server mode (no remote host specified)
    else if (host == NULL || strlen(host) == 0) {
        // Server mode: bind to all interfaces
        hints.ai_flags = AI_PASSIVE;
        bindHost = NULL;  // INADDR_ANY
    }
    else {
        // Client mode: use remote host as is
        bindHost = host;
    }

    // Call getaddrinfo with the resolved host
    result = getaddrinfo(bindHost, port, &hints, &address);

    // Clean up UTF8 strings (Wolfram memory management)
    if (host) libData->UTF8String_disown(host);
    if (port) libData->UTF8String_disown(port);
    if (localIP) libData->UTF8String_disown(localIP);

    if (result != 0) {
        return LIBRARY_FUNCTION_ERROR;
    }

    // Return the addrinfo pointer as integer to Wolfram
    uintptr_t addressPtr = (uintptr_t)address;
    MArgument_setInteger(Res, (mint)addressPtr);
    return LIBRARY_NO_ERROR;
}

/*socketAddressInfoRemove[addressPtr] -> successStatus*/
DLLEXPORT int socketAddressInfoRemove(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res) {
    uintptr_t addressPtr = (uintptr_t)MArgument_getInteger(Args[0]); // address pointer as integer
    struct addrinfo *address = (struct addrinfo*)addressPtr;

    if (address == NULL) {
        return LIBRARY_FUNCTION_ERROR;
    }

    freeaddrinfo(address);
    return LIBRARY_NO_ERROR;
}

DLLEXPORT int socketAddressInfoListCreate(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res) {
    if (Argc != 2) return LIBRARY_FUNCTION_ERROR;

    MTensor addressInfos = MArgument_getMTensor(Args[0]);
    mint *addressInfoData = libData->MTensor_getIntegerData(addressInfos);
    mint length = MArgument_getInteger(Args[1]);

    struct addrinfo **addresInfoArray = malloc(sizeof(struct addrinfo*) * length);
    if (!addresInfoArray) {
        return LIBRARY_FUNCTION_ERROR;
    }

    for (mint i = 0; i < length; i++) {
        addresInfoArray[i] = (struct addrinfo*)(uintptr_t)addressInfoData[i];
    }

    MArgument_setInteger(Res, (mint)(uintptr_t)addresInfoArray);
    return LIBRARY_NO_ERROR;
}

DLLEXPORT int socketAddressInfoListRemove(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res) {
    if (Argc != 1) return LIBRARY_FUNCTION_ERROR;

    mint addressInfos = MArgument_getInteger(Args[0]);
    void *addressInfosPtr = (void *)(uintptr_t)addressInfos;
    free(addressInfosPtr);

    return LIBRARY_NO_ERROR;
}