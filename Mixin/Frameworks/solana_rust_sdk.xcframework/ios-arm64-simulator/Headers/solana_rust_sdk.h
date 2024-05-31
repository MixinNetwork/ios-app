#include <stdarg.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>

typedef enum SolanaErrorCode {
  SolanaErrorCodeSuccess = 0,
  SolanaErrorCodeNullPointer = -1,
  SolanaErrorCodeInvalidSeed = -2,
  SolanaErrorCodePublicKeyToString = -3,
  SolanaErrorCodeSignatureToString = -4,
  SolanaErrorCodeSignTransaction = -5,
  SolanaErrorCodeSerializeTransaction = -6,
  SolanaErrorCodeDeserializeTransaction = -7,
  SolanaErrorCodeNotLegacyMessage = -8,
  SolanaErrorCodeNotFound = -9,
} SolanaErrorCode;

extern const uint64_t SOLANA_LAMPORTS_PER_SOL;

void solana_free_string(const char *ptr);

enum SolanaErrorCode solana_public_key_from_seed(const uint8_t *seed,
                                                 size_t seed_len,
                                                 const char **out);

enum SolanaErrorCode solana_sign_message(const uint8_t *seed,
                                         size_t seed_len,
                                         const uint8_t *msg,
                                         size_t msg_len,
                                         const char **out);

void solana_free_transaction(void *txn);

void *solana_deserialize_transaction(const uint8_t *txn, size_t txn_len);

enum SolanaErrorCode solana_sign_transaction(void *txn,
                                             const uint8_t *recent_blockhash,
                                             size_t recent_blockhash_len,
                                             const uint8_t *seed,
                                             size_t seed_len,
                                             const char **out);

enum SolanaErrorCode solana_calculate_fee(void *txn,
                                          uint64_t lamports_per_signature,
                                          uint64_t *out);

enum SolanaErrorCode solana_balance_change(void *txn, uint64_t *change, const char **mint);
