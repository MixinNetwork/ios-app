//
//  setup.c
//  libsignal-protocol-swift iOS
//
//  Created by User on 15.02.18.
//  Copyright © 2018 User. All rights reserved.
//

#include "setup.h"
#include <libsignal_protocol_c/signal_protocol.h>

#include <pthread.h>

pthread_mutex_t global_mutex;
pthread_mutexattr_t global_mutex_attr;

signal_protocol_store_context* setup_store_context(signal_context *global_context);
int set_locking(signal_context *global_context);
void test_log(int level, const char *message, size_t len, void *user_data);

void (*printSignalLog)(const char *);

void *signal_setup(void) {
    signal_context *global_context;
    int result = signal_context_create(&global_context, 0);
    if (result != 0) {
        return 0;
    }

    result = set_locking(global_context);
    if (result != 0) {
        signal_context_destroy(global_context);
        return 0;
    }

    result = setup_crypto_provider(global_context);
    if (result != 0) {
        signal_context_destroy(global_context);
        pthread_mutex_destroy(&global_mutex);
        pthread_mutexattr_destroy(&global_mutex_attr);
        return 0;
    }

    signal_context_set_log_function(global_context, test_log);
    
    return (void*) global_context;
}

void signal_destroy(void *global_context) {

    signal_context_destroy((signal_context*) global_context);

    pthread_mutex_destroy(&global_mutex);
    pthread_mutexattr_destroy(&global_mutex_attr);
}

// MARK: Locking functions

void test_lock(void *user_data) {
    pthread_mutex_lock(&global_mutex);
}

void test_unlock(void *user_data) {
    pthread_mutex_unlock(&global_mutex);
}

int set_locking(signal_context *global_context) {
    pthread_mutexattr_init(&global_mutex_attr);
    pthread_mutexattr_settype(&global_mutex_attr, PTHREAD_MUTEX_RECURSIVE);
    pthread_mutex_init(&global_mutex, &global_mutex_attr);

    return signal_context_set_locking_functions(global_context, test_lock, test_unlock);
}

void test_log(int level, const char *message, size_t len, void *user_data) {
    switch(level) {
        case SG_LOG_ERROR:
            fprintf(stderr, "[ERROR] %s\n", message);
            break;
        case SG_LOG_WARNING:
            fprintf(stderr, "[WARNING] %s\n", message);
            break;
        case SG_LOG_NOTICE:
            fprintf(stderr, "[NOTICE] %s\n", message);
            break;
        case SG_LOG_INFO:
            fprintf(stderr, "[INFO] %s\n", message);
            break;
        case SG_LOG_DEBUG:
            fprintf(stderr, "[DEBUG] %s\n", message);
            break;
        default:
            fprintf(stderr, "[%d] %s\n", level, message);
            break;
    }
    if (printSignalLog) {
        printSignalLog(message);
    }
}
