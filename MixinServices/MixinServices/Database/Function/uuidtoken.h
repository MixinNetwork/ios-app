#ifndef uuidtoken_h
#define uuidtoken_h

/*
 These function converts UUID string into token representation
 and vice versa. The UUID is a string of the form
 1b4e28ba-2fa1-11d2-883f-b9a761bde3fb (in printf format
 "%08x-%04x-%04x-%04x-%012x"). There're no bounds checking, UUID
 validation or UTF-8/ASCII encode verifying, they see any input as
 36 bytes of ASCII letters, following completely the GIGO concept.
 */

char *utot(const char *uuid);
char *ttou(const char *token);

#endif /* uuidtoken_h */
