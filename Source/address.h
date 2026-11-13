#ifndef ADDRESS_H
#define ADDRESS_H


#include "common.h"


struct sockaddr_storage *MArgument_getAddressStorage(WolframLibraryData libData, MArgument arg);


void MArgument_setAddressStorage(WolframLibraryData libData, MArgument res, struct addrinfo *addressInfo);


void DataStore_addAddressStorage(WolframLibraryData libData, DataStore dataStore, struct sockaddr_storage *addressStorage);


#endif