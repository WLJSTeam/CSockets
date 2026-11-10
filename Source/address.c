#include "address.h"


struct addrinfo *MArgument_getAddressInfo(WolframLibraryData libData, MArgument arg)
{
    (void)libData;
    return (struct addrinfo *)(uintptr_t)MArgument_getInteger(arg);
}


void MArgument_setAddressInfo(WolframLibraryData libData, MArgument res, struct addrinfo *addressInfo)
{
    (void)libData;
    MArgument_setInteger(res, (mint)(uintptr_t)addressInfo);
}


DLLEXPORT int socketAddressInfoCreate(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    char *host = MArgument_getUTF8String(Args[0]);
    char *port = MArgument_getUTF8String(Args[1]);
    int ai_family = (int)MArgument_getInteger(Args[2]);
    int ai_socktype = (int)MArgument_getInteger(Args[3]);
    int ai_protocol = (int)MArgument_getInteger(Args[4]);
    char *localIP = MArgument_getUTF8String(Args[5]);

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

    MArgument_setAddressInfo(libData, Res, address);
    return LIBRARY_NO_ERROR;
}


DLLEXPORT int socketAddressInfoRemove(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    (void)Res;
    if (Argc != 1) {
        libData->Message("socketAddressInfoRemove: invalid argument count");
        return LIBRARY_FUNCTION_ERROR;
    }

    struct addrinfo *addressInfo = MArgument_getAddressInfo(libData, Args[0]);

    if (addressInfo == NULL) {
        return LIBRARY_FUNCTION_ERROR;
    }

    freeaddrinfo(addressInfo);
    return LIBRARY_NO_ERROR;
}