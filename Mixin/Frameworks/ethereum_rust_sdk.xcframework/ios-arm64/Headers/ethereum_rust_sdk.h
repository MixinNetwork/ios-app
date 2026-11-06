#ifndef ETHEREUM_RUST_SDK_H
#define ETHEREUM_RUST_SDK_H

#include <stdarg.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>

typedef enum EVMErrorCode {
  EVMErrorCode_Success = 0,
  EVMErrorCode_NullPointer = -1,
  EVMErrorCode_InvalidInput = -2,
  EVMErrorCode_InvalidPrivateKey = -3,
  EVMErrorCode_InvalidAddress = -4,
  EVMErrorCode_InvalidTransaction = -5,
  EVMErrorCode_InvalidTypedData = -6,
  EVMErrorCode_SigningFailed = -7,
  EVMErrorCode_Panic = -8,
  EVMErrorCode_IntegerOverflow = -9,
  EVMErrorCode_InvalidSignature = -10,
  EVMErrorCode_InvalidChainIDInTypedData = -11,
} EVMErrorCode;

/**
 * Opaque immutable Alloy EIP-1559 transaction. Release with evm_free_transaction.
 */
typedef struct EVMTransaction EVMTransaction;

/**
 * Borrowed bytes. A null pointer is allowed only when len is zero.
 */
typedef struct EVMBytes {
  const uint8_t *data;
  size_t len;
} EVMBytes;

/**
 * Owned output bytes. Free with evm_free_buffer; do not modify the fields.
 */
typedef struct EVMBuffer {
  uint8_t *data;
  size_t len;
} EVMBuffer;

typedef struct EVMAddressBytes {
  uint8_t bytes[20];
} EVMAddressBytes;

/**
 * Unsigned 256-bit integer in big-endian byte order.
 */
typedef struct EVMUInt256 {
  uint8_t bytes[32];
} EVMUInt256;

/**
 * Locally confirmed transfer, independent of the untrusted server payload.
 * Token flags must be 0 (native currency) or 1 (ERC-20); amounts are base units.
 */
typedef struct EVMGaslessTransfer {
  uint64_t chain_id;
  struct EVMAddressBytes sender;
  struct EVMAddressBytes recipient;
  uint8_t has_token;
  struct EVMAddressBytes token;
  struct EVMUInt256 amount;
  uint8_t has_fee_token;
  struct EVMAddressBytes fee_token;
  struct EVMUInt256 fee_amount;
} EVMGaslessTransfer;

/**
 * Unsigned 128-bit integer in big-endian byte order.
 */
typedef struct EVMUInt128 {
  uint8_t bytes[16];
} EVMUInt128;

/**
 * Borrowed EIP-1559 fields. All pointers must remain valid for the call.
 * has_destination must be 0 (contract creation) or 1 (message call).
 */
typedef struct EVMTransactionFields {
  uint64_t chain_id;
  uint64_t nonce;
  struct EVMUInt128 max_priority_fee_per_gas;
  struct EVMUInt128 max_fee_per_gas;
  uint64_t gas_limit;
  uint8_t has_destination;
  struct EVMAddressBytes destination;
  struct EVMUInt256 amount;
  struct EVMBytes data;
} EVMTransactionFields;

/**
 * Borrowed fields required for fee estimation and transaction replacement.
 * data remains valid until the transaction owner is freed.
 */
typedef struct EVMTransactionInfo {
  uint64_t chain_id;
  uint64_t nonce;
  uint8_t has_destination;
  struct EVMAddressBytes destination;
  struct EVMUInt256 amount;
  struct EVMBytes data;
} EVMTransactionInfo;

/**
 * Derive a 20-byte address from a private key.
 * # Safety
 * Input slices must be readable for their lengths. out must be writable and
 * must not alias any input. No input is retained. On error out is empty.
 */
enum EVMErrorCode evm_address(struct EVMBytes key, struct EVMBuffer *out);

/**
 * Format a 20-byte address as EIP-55 UTF-8 (not NUL-terminated).
 * # Safety
 * Input slices must be readable; out must be writable and not alias inputs.
 */
enum EVMErrorCode evm_checksum_address(struct EVMBytes address, struct EVMBuffer *out);

/**
 * Sign arbitrary bytes with EIP-191. Returns r || s || v (65 bytes, v = 27/28).
 * # Safety
 * Input slices must be readable; out must be writable and not alias inputs.
 */
enum EVMErrorCode evm_sign_personal_message(struct EVMBytes message,
                                            struct EVMBytes key,
                                            struct EVMBuffer *out);

/**
 * Sign a 32-byte digest directly. Returns r || s || v (v = 27/28).
 * # Safety
 * Input slices must be readable; out must be writable and not alias inputs.
 */
enum EVMErrorCode evm_sign_hash(struct EVMBytes hash, struct EVMBytes key, struct EVMBuffer *out);

/**
 * Recover a 65-byte uncompressed SEC1 public key (0x04 || X || Y) from a
 * 32-byte digest and r || s || v signature. v must be 0/1 or 27/28.
 * The digest is used directly without additional hashing or message prefixes.
 * # Safety
 * Input slices must be readable; out must be writable and not alias inputs.
 * On error out is empty. Free successful output with evm_free_buffer.
 */
enum EVMErrorCode evm_recover_public_key(struct EVMBytes hash,
                                         struct EVMBytes signature,
                                         struct EVMBuffer *out);

/**
 * Validate a gasless transfer against locally confirmed fields, returning the rebuilt
 * user-operation digest followed by the optional EIP-7702 authorization digest.
 * No digest is returned unless the entire payload passes validation.
 * # Safety
 * Input slices and expected must be readable; out must be writable and not alias inputs.
 */
enum EVMErrorCode evm_validate_gasless_transfer(struct EVMBytes json,
                                                const struct EVMGaslessTransfer *expected,
                                                struct EVMBuffer *out);

/**
 * Hash EIP-712 UTF-8 JSON, returning 32 bytes.
 * # Safety
 * Input slices must be readable; out must be writable and not alias inputs.
 */
enum EVMErrorCode evm_typed_data_hash(struct EVMBytes json, struct EVMBuffer *out);

/**
 * Validate EIP-712 JSON and return its formatted message as UTF-8.
 * # Safety
 * Input slices must be readable; out must be writable and not alias inputs.
 */
enum EVMErrorCode evm_typed_data_description(struct EVMBytes json, struct EVMBuffer *out);

/**
 * Validate domain.chainId against the signing chain. A missing chain ID is allowed.
 * # Safety
 * The input slice must be readable for its length. No input is retained.
 */
enum EVMErrorCode evm_validate_typed_data_chain_id(struct EVMBytes json,
                                                   uint64_t expected_chain_id);

/**
 * Sign EIP-712 UTF-8 JSON after validating domain.chainId against the signing chain.
 * Returns r || s || v (v = 27/28). A missing chain ID is allowed.
 * # Safety
 * Input slices must be readable; out must be writable and not alias inputs.
 */
enum EVMErrorCode evm_sign_typed_data(struct EVMBytes json,
                                      uint64_t expected_chain_id,
                                      struct EVMBytes key,
                                      struct EVMBuffer *out);

/**
 * Construct an owned EIP-1559 transaction. All fields are copied; no input is retained.
 * # Safety
 * fields and its slices must be readable. out must be writable and not alias inputs.
 * On success free the handle with evm_free_transaction. On error out is null.
 */
enum EVMErrorCode evm_transaction_new(const struct EVMTransactionFields *fields,
                                      struct EVMTransaction **out);

/**
 * Encode the unsigned type-2 signing payload from an owned transaction.
 * # Safety
 * owner must be a live transaction. out must be writable and not alias its data.
 */
enum EVMErrorCode evm_transaction_encode(const struct EVMTransaction *owner, struct EVMBuffer *out);

/**
 * Sign and encode a type-2 envelope. Neither the transaction nor the key is retained or mutated.
 * # Safety
 * owner must be live; key must be readable. out must be writable and not alias inputs.
 */
enum EVMErrorCode evm_transaction_sign(const struct EVMTransaction *owner,
                                       struct EVMBytes key,
                                       struct EVMBuffer *out);

/**
 * Decode canonical signed or unsigned type-2 bytes into an unsigned template.
 * Access lists are discarded; encoded and re-signed transactions always use an empty list.
 * # Safety
 * raw must be readable. out must be writable and not alias inputs.
 * On success free the handle with evm_free_transaction. On error out is null.
 */
enum EVMErrorCode evm_transaction_decode(struct EVMBytes raw, struct EVMTransaction **out);

/**
 * Borrow only the fields needed by the app. The data slice lives as long as owner.
 * # Safety
 * owner must be live. out must be writable and not alias owner or its data.
 */
enum EVMErrorCode evm_transaction_get_info(const struct EVMTransaction *owner,
                                           struct EVMTransactionInfo *out);

/**
 * Return a new transaction with updated nonce and fees. The original is unchanged.
 * # Safety
 * owner must be live. out must be writable and not alias owner or its data.
 */
enum EVMErrorCode evm_transaction_with_fees(const struct EVMTransaction *owner,
                                            uint64_t nonce,
                                            uint64_t gas_limit,
                                            struct EVMUInt128 max_priority_fee_per_gas,
                                            struct EVMUInt128 max_fee_per_gas,
                                            struct EVMTransaction **out);

/**
 * Create a zero-value cancellation call with the source chain ID and nonce.
 * Fees and gas are zero until replaced with evm_transaction_with_fees.
 * # Safety
 * owner must be live. out must be writable and not alias owner or its data.
 */
enum EVMErrorCode evm_transaction_cancellation(const struct EVMTransaction *owner,
                                               struct EVMAddressBytes destination,
                                               struct EVMTransaction **out);

/**
 * Release an owned buffer and reset it to empty. Null is accepted.
 * # Safety
 * value must be writable and contain an unmodified, unfreed output buffer,
 * or an empty buffer. Do not free copies of the same buffer.
 */
void evm_free_buffer(struct EVMBuffer *value);

/**
 * Release an owned transaction and invalidate its borrowed data slices. Null is accepted.
 * # Safety
 * owner must be null or an unfreed transaction handle.
 */
void evm_free_transaction(struct EVMTransaction *owner);

/**
 * Parse an unsigned decimal integer, rejecting signs, fractions, and overflow.
 * # Safety
 * text must be readable. out must be writable and not alias input.
 */
enum EVMErrorCode evm_uint256_from_decimal(struct EVMBytes text, struct EVMUInt256 *out);

/**
 * Parse hexadecimal digits with an optional lowercase 0x prefix. Reject overflow.
 * # Safety
 * text must be readable. out must be writable and not alias input.
 */
enum EVMErrorCode evm_uint256_from_hex(struct EVMBytes text, struct EVMUInt256 *out);

/**
 * Format a quantity as unsigned decimal UTF-8.
 * # Safety
 * out must be writable and contain no unfreed buffer.
 */
enum EVMErrorCode evm_uint256_to_decimal(struct EVMUInt256 value, struct EVMBuffer *out);

/**
 * Format a canonical JSON-RPC hex quantity, including 0x and no leading zeros.
 * # Safety
 * out must be writable and contain no unfreed buffer.
 */
enum EVMErrorCode evm_uint256_to_hex(struct EVMUInt256 value, struct EVMBuffer *out);

/**
 * Multiply two quantities, rejecting overflow rather than wrapping.
 * # Safety
 * out must be writable.
 */
enum EVMErrorCode evm_uint256_multiply(struct EVMUInt256 lhs,
                                       struct EVMUInt256 rhs,
                                       struct EVMUInt256 *out);

/**
 * Integer division, rounding down. A zero divisor returns InvalidInput.
 * # Safety
 * out must be writable.
 */
enum EVMErrorCode evm_uint256_divide(struct EVMUInt256 value,
                                     uint64_t divisor,
                                     struct EVMUInt256 *out);

#endif  /* ETHEREUM_RUST_SDK_H */
