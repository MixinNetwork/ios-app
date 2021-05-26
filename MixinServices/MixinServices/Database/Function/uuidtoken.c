#include "uuidtoken.h"
#include <string.h>

char *utot(const char *uuid) {
    char *token = strdup(uuid);
    for (uint8_t i = 0; i < 36; i++) {
        if (token[i] == '-') {
            token[i] = 'z';
        } else if (token[i] >= '0' && token[i] <= '9') {
            token[i] += 55;
        }
    }
    return token;
}

char *ttou(const char *token) {
    char *uuid = strdup(token);
    for (uint8_t i = 0; i < 36; i++) {
        if (uuid[i] == 'z') {
            uuid[i] = '-';
        } else if (uuid[i] > 'f') {
            uuid[i] -= 55;
        }
    }
    return uuid;
}
