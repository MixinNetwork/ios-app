#include <stdarg.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>

typedef enum BitcoinErrorCode {
  BitcoinErrorCodeSuccess = 0,
  BitcoinErrorCodeNullPointer = -1,
  BitcoinErrorCodeInvalidString = -2,
  BitcoinErrorCodeInvalidWIF = -3,
  BitcoinErrorCodeGeneratePublicKey = -4,
  BitcoinErrorCodePublicKeyToString = -5,
  BitcoinErrorCodeInvalidMnemonic = -6,
  BitcoinErrorCodeDeriveMasterKey = -7,
  BitcoinErrorCodeInvalidDerivationPath = -8,
  BitcoinErrorCodeDeriveChildKey = -9,
  BitcoinErrorCodeInvalidInput = -10,
  BitcoinErrorCodeInvalidPrivateKey = -11,
  BitcoinErrorCodeInvalidPrivateKeyLength = -12,
  BitcoinErrorCodePrivateKeyToString = -13,
  BitcoinErrorCodeInvalidUTXOCount = -20,
  BitcoinErrorCodeInvalidAddress = -21,
  BitcoinErrorCodeInsufficientFunds = -22,
  BitcoinErrorCodeInvalidNetwork = -23,
  BitcoinErrorCodeGenerateWPKH = -24,
  BitcoinErrorCodeSighashError = -25,
  BitcoinErrorCodeSecpError = -26,
  BitcoinErrorCodeEncodeTransaction = -27,
  BitcoinErrorCodeDecodeTransaction = -28,
} BitcoinErrorCode;

typedef struct BitcoinUTXO {
  uint8_t txid[32];
  uint32_t vout;
  uint64_t value;
} BitcoinUTXO;

typedef struct BitcoinTransactionOutput {
  char *address;
  uint64_t value;
} BitcoinTransactionOutput;

extern const size_t BITCOIN_PRIVATE_KEY_LENGTH;

extern const uint64_t BITCOIN_P2WPKH_DUST;

void bitcoin_free_string(const char *ptr);

void bitcoin_free_bytes(unsigned char *ptr, size_t len);

void bitcoin_free_utxos(struct BitcoinUTXO *ptr, size_t len);

void bitcoin_free_transaction_outputs(struct BitcoinTransactionOutput *outputs, size_t len);

bool bitcoin_is_valid_address(const char *input);

enum BitcoinErrorCode bitcoin_wif_string(const unsigned char *private_key_bytes,
                                         size_t private_key_len,
                                         const char **out);

enum BitcoinErrorCode bitcoin_private_key_bytes_from_wif(const char *wif,
                                                         const unsigned char **out_ptr,
                                                         size_t *out_len);

enum BitcoinErrorCode bitcoin_private_key_bytes_from_mnemonics(const char *mnemonic,
                                                               const char *derivation_path,
                                                               const unsigned char **out_ptr,
                                                               size_t *out_len);

enum BitcoinErrorCode bitcoin_segwit_address(const unsigned char *key_bytes,
                                             size_t key_len,
                                             const char **out);

enum BitcoinErrorCode bitcoin_sign_message_compressed(const char *message,
                                                      const uint8_t *privkey_bytes,
                                                      size_t privkey_len,
                                                      const char **out);

enum BitcoinErrorCode bitcoin_sign_p2wpkh_transaction(const struct BitcoinUTXO *utxos_ptr,
                                                      size_t utxos_len,
                                                      const char *receiver_address,
                                                      uint64_t send_amount,
                                                      uint64_t fee,
                                                      const uint8_t *privkey_bytes,
                                                      size_t privkey_len,
                                                      const char **out_tx_hex,
                                                      size_t *out_tx_vsize,
                                                      const char **out_txid,
                                                      uint64_t *out_change_amount);

enum BitcoinErrorCode bitcoin_decode_p2wpkh_transaction(const char *tx,
                                                        struct BitcoinUTXO **out_inputs,
                                                        size_t *out_inputs_len,
                                                        struct BitcoinTransactionOutput **out_outputs,
                                                        size_t *out_outputs_len);
