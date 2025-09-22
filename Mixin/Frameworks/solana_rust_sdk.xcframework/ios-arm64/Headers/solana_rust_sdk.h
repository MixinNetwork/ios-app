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
  SolanaErrorCodeInvalidString = -10,
  SolanaErrorCodeInvalidPublicKey = -11,
  SolanaErrorCodeBuildSPLInstruction = -12,
  SolanaErrorCodeTransactionToString = -13,
  SolanaErrorCodeNotOnCurve = -14,
  SolanaErrorCodeInvalidProgramID = -15,
} SolanaErrorCode;

typedef enum SolanaSignatureFormat {
  SolanaSignatureFormatBase58,
  SolanaSignatureFormatHex,
} SolanaSignatureFormat;

typedef struct SolanaPriorityFee {
  uint64_t price;
  uint32_t limit;
} SolanaPriorityFee;

extern const uint64_t SOLANA_LAMPORTS_PER_SOL;

void solana_free_string(const char *ptr);

enum SolanaErrorCode solana_public_key_from_seed(const uint8_t *seed,
                                                 size_t seed_len,
                                                 const char **out);

bool solana_is_valid_public_key(const char *string);

enum SolanaErrorCode solana_sign_message(const uint8_t *seed,
                                         size_t seed_len,
                                         const uint8_t *msg,
                                         size_t msg_len,
                                         enum SolanaSignatureFormat format,
                                         const char **out);

void solana_free_transaction(const void *txn);

enum SolanaErrorCode solana_base64_encode_transaction(const void *txn, const char **out);

const void *solana_deserialize_transaction(const uint8_t *txn, size_t txn_len);

bool solana_transaction_contains_set_authority(const void *txn);

int16_t solana_transaction_number_of_required_signatures(const void *txn);

enum SolanaErrorCode solana_sign_transaction(const void *txn,
                                             const uint8_t *recent_blockhash,
                                             size_t recent_blockhash_len,
                                             const uint8_t *seed,
                                             size_t seed_len,
                                             const char **out);

enum SolanaErrorCode solana_calculate_fee(const void *txn,
                                          uint64_t lamports_per_signature,
                                          uint64_t *out);

enum SolanaErrorCode solana_balance_change(const void *txn, uint64_t *change, const char **mint);

enum SolanaErrorCode solana_new_sol_transaction(const char *from,
                                                const char *to,
                                                uint64_t lamports,
                                                const struct SolanaPriorityFee *priority_fee,
                                                const void **out);

enum SolanaErrorCode solana_associated_token_account(const char *wallet_address,
                                                     const char *mint,
                                                     const char *token_program_id,
                                                     const char **out);

enum SolanaErrorCode solana_new_spl_token_transaction(const char *from,
                                                      const char *to,
                                                      bool create_to_ata,
                                                      const char *token_program_id,
                                                      const char *mint,
                                                      uint64_t amount,
                                                      uint8_t decimals,
                                                      const struct SolanaPriorityFee *priority_fee,
                                                      const void **out);
