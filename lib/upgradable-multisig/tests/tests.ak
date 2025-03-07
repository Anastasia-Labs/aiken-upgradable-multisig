use aiken/collection/dict
use aiken/crypto.{blake2b_256}
use aiken/primitive/bytearray
use cardano/address.{Address, Script, VerificationKey}
use cardano/assets.{ada_asset_name, ada_policy_id, add}
use cardano/transaction.{
  InlineDatum, Input, Output, OutputReference, Transaction,
}
use upgradable_multisig/types.{MultisigDatum}

// Generate a bytearray with blake2b_256
pub fn test_224_01() {
  bytearray.take(blake2b_256(#"01"), 28)
}

// Generate a bytearray with blake2b_256
pub fn test_224_02() {
  bytearray.take(blake2b_256(#"02"), 28)
}

// Generate a bytearray with blake2b_256
pub fn test_224_03() {
  bytearray.take(blake2b_256(#"03"), 28)
}

pub fn test_224_04() {
  bytearray.take(blake2b_256(#"04"), 28)
}

pub fn test_224_05() {
  bytearray.take(blake2b_256(#"05"), 28)
}

pub fn test_224_06() {
  bytearray.take(blake2b_256(#"06"), 28)
}

// Generate a bytearray with blake2b_256
pub fn test_policy() {
  bytearray.take(blake2b_256(#"07"), 28)
}

pub fn test_withdraw_pkh() {
  bytearray.take(blake2b_256(#"08"), 28)
}

pub fn test_input_utxo_01() {
  OutputReference { transaction_id: test_224_01(), output_index: 1 }
}

pub fn test_input_utxo_02(utxo_hash) {
  OutputReference { transaction_id: utxo_hash, output_index: 1 }
}

pub fn test_multisig_datum(signitories, signer_count, limit_qty) {
  MultisigDatum {
    signers: signitories,
    threshold: signer_count,
    fund_policy_id: ada_policy_id,
    fund_asset_name: ada_asset_name,
    spending_limit: limit_qty,
  }
}

pub fn test_context_input_01(output_ref, own_cs, token_value, datum) {
  Input {
    output_reference: output_ref,
    output: Output {
      address: Address(Script(own_cs), None),
      value: token_value,
      datum: InlineDatum(datum),
      reference_script: None,
    },
  }
}

pub fn test_context_input_02(output_ref, own_cs, minted_value, datum) {
  Input {
    output_reference: output_ref,
    output: Output {
      address: Address(Script(own_cs), None),
      value: add(minted_value, ada_policy_id, ada_asset_name, 4_000_000),
      datum: InlineDatum(datum),
      reference_script: None,
    },
  }
}

// Create a UTxO
pub fn test_utxo_02(own_cs, minted_value, lovelace, datum) {
  Output {
    address: Address {
      payment_credential: Script(own_cs),
      stake_credential: None,
    },
    value: add(minted_value, ada_policy_id, ada_asset_name, lovelace),
    datum: InlineDatum(datum),
    reference_script: None,
  }
}

pub fn test_user_utxo(pubkey_hash: ByteArray, token_value, datum) {
  Output {
    address: Address {
      payment_credential: VerificationKey(pubkey_hash),
      stake_credential: None,
    },
    value: token_value,
    datum: InlineDatum(datum),
    reference_script: None,
  }
}

pub fn test_spend_transaction(
  main_inputs,
  ref_inputs,
  main_outputs,
  minted_value,
  time_range,
  tx_hash: ByteArray,
) {
  Transaction {
    inputs: main_inputs,
    reference_inputs: ref_inputs,
    outputs: main_outputs,
    fee: 0,
    mint: minted_value,
    certificates: [],
    withdrawals: [],
    validity_range: time_range,
    extra_signatories: [],
    redeemers: [],
    datums: dict.empty,
    id: tx_hash,
    votes: [],
    proposal_procedures: [],
    current_treasury_amount: None,
    treasury_donation: None,
  }
}
