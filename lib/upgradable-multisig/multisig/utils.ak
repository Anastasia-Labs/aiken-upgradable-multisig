use aiken/builtin
use aiken/collection/list
use aiken/crypto.{Blake2b_256, Hash, VerificationKeyHash, sha3_256}
use aiken/primitive/bytearray
use aiken_scott_utils/list as scott_list
use cardano/assets.{AssetName, PolicyId, quantity_of}
use cardano/transaction.{Input, Output, OutputReference, Transaction}
use upgradable_multisig/types.{MultisigDatum, PubKeyHash}

pub fn get_input_by_token(
  inputs: List<Input>,
  policy_id: PolicyId,
  token_name: ByteArray,
) -> Option<Input> {
  list.find(
    inputs,
    fn(input) { quantity_of(input.output.value, policy_id, token_name) > 0 },
  )
}

//  Check all the signatures are correct
pub fn validate_multisig_datum(
  datum: MultisigDatum,
  extra_signatories: List<VerificationKeyHash>,
) -> Bool {
  let datum_signers = datum.signers
  let signers_nr = list.length(datum_signers)

  let
    all_signers_have_signed,
    _,
  <-
    scott_list.foldl2(
      datum_signers,
      True,
      extra_signatories,
      fn(datum_signer, have_signed_so_far, remaining_tx_signatories, return) {
        let relevant_signatories =
          remaining_tx_signatories
            |> list.drop_while(
                fn(s) { bytearray.compare(s, datum_signer) == Less },
              )

        let expected_signer = builtin.head_list(relevant_signatories)
        return(
          have_signed_so_far && expected_signer == datum_signer,
          relevant_signatories,
        )
      },
    )

  (signers_nr >= datum.threshold)? && (datum.threshold > 0)? && all_signers_have_signed?
}

fn has_enough_signers(
  all_signers: List<PubKeyHash>,
  threshold: Int,
  actual_signers: List<PubKeyHash>,
) -> Bool {
  when all_signers is {
    [] -> False
    [head, ..tail] ->
      if list.has(actual_signers, head) {
        if threshold > 1 {
          has_enough_signers(tail, threshold - 1, actual_signers)
        } else {
          True
        }
      } else {
        has_enough_signers(tail, threshold, actual_signers)
      }
  }
}

pub fn signed_within_threshold(
  datum: MultisigDatum,
  extra_signatories: List<PubKeyHash>,
) -> Bool {
  has_enough_signers(datum.signers, datum.threshold, extra_signatories)
}

/// Calculate a unique token name from a `TxId#Idx` and prefix. Can be combined
/// with the `find` module to create unique token names from the first input
/// utxo inside the transaction.
///
/// ```aiken
/// values.unique_token_name(tx_id, tx_idx, cip68.prefix_333)
/// ```
pub fn unique_token_name(
  txid: Hash<Blake2b_256, Transaction>,
  idx: Int,
  prefix: ByteArray,
) -> AssetName {
  let txid_hash: ByteArray = sha3_256(txid)
  let prepend_index: ByteArray = bytearray.push(txid_hash, idx)
  let prepend_prefix: ByteArray = bytearray.concat(prefix, prepend_index)
  bytearray.slice(prepend_prefix, 0, 31)
}

// TODO: Find out whether token name is 28 or 32 bytes.
pub fn multisig_token_name(own_ref: OutputReference) -> ByteArray {
  // let sig_tkn_name =
  unique_token_name(own_ref.transaction_id, own_ref.output_index, "multisig")
}
