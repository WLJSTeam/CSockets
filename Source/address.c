#include "address.h"


struct sockaddr_storage *MArgument_getAddressStorage(WolframLibraryData libData, MArgument arg)
{
    MNumericArray addressArray = MArgument_getMNumericArray(arg);
    struct sockaddr_storage *addressStorage = (struct sockaddr_storage *)libData->numericarrayLibraryFunctions->MNumericArray_getData(addressArray);
    libData->numericarrayLibraryFunctions->MNumericArray_disown(addressArray);
    return addressStorage;
}


void MArgument_setAddressStorage(WolframLibraryData libData, MArgument res, struct addrinfo *addressInfo)
{
    mint length = (mint)sizeof(struct sockaddr_storage);
    MNumericArray addressArray;
    libData->numericarrayLibraryFunctions->MNumericArray_new(MNumericArray_Type_UBit8, 1, &length, &addressArray);

    struct sockaddr_storage *addressStorage = (struct sockaddr_storage*)libData->numericarrayLibraryFunctions->MNumericArray_getData(addressArray);
    ZeroMemory(addressStorage, sizeof(struct sockaddr_storage));

    size_t addressSize = addressInfo->ai_addrlen;
    if (addressSize > sizeof(struct sockaddr_storage)) {
        addressSize = sizeof(struct sockaddr_storage);
    }

    memcpy(addressStorage, addressInfo->ai_addr, addressSize);

    MArgument_setMNumericArray(res, addressArray);
}


void DataStore_addAddressStorage(WolframLibraryData libData, DataStore dataStore, struct sockaddr_storage *addressStorage)
{
    mint length = (mint)sizeof(struct sockaddr_storage);
    MNumericArray addressArray;
    libData->numericarrayLibraryFunctions->MNumericArray_new(MNumericArray_Type_UBit8, 1, &length, &addressArray);

    struct sockaddr_storage *arrayData = (struct sockaddr_storage*)libData->numericarrayLibraryFunctions->MNumericArray_getData(addressArray);
    ZeroMemory(arrayData, sizeof(struct sockaddr_storage));
    memcpy(arrayData, addressStorage, sizeof(struct sockaddr_storage));

    libData->ioLibraryFunctions->DataStore_addMNumericArray(dataStore, addressArray);
}


DLLEXPORT int socketAddressStorageCreate(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res)
{
    if (Argc != 6) {
        libData->Message("socketAddressInfoCreate: invalid argument count");
        return LIBRARY_FUNCTION_ERROR;
    }

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

    if (result != 0 || address == NULL) {
        if (address) {
            freeaddrinfo(address);
        }
        return LIBRARY_FUNCTION_ERROR;
    }

    MArgument_setAddressStorage(libData, Res, address);
    freeaddrinfo(address);
    return LIBRARY_NO_ERROR;
}
