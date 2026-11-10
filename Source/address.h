#ifndef ADDRESS_H
#define ADDRESS_H


#include "common.h"


struct addrinfo *MArgument_getAddressInfo(WolframLibraryData libData, MArgument arg);


void MArgument_setAddressInfo(WolframLibraryData libData, MArgument res, struct addrinfo *addressInfo);


#endif