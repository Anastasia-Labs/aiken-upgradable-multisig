use aiken/bytearray
use aiken/dict
use aiken/hash.{blake2b_256}
use aiken/transaction.{
  InlineDatum, Input, Output, OutputReference, ScriptContext, Spend, Transaction,
  TransactionId,
}
use aiken/transaction/credential.{Address, ScriptCredential}
use aiken/transaction/value
use upgradable_multisig/types.{AssetClass, MultisigDatum}

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
  OutputReference {
    transaction_id: TransactionId { hash: test_224_01() },
    output_index: 1,
  }
}

pub fn test_input_utxo_02(utxo_hash) {
  OutputReference {
    transaction_id: TransactionId { hash: utxo_hash },
    output_index: 1,
  }
}

pub fn test_multisig_datum(signitories, signer_count, limit_qty) {
  MultisigDatum {
    signers: signitories,
    threshold: signer_count,
    funds: AssetClass {
      policy_id: value.ada_policy_id,
      asset_name: value.ada_asset_name,
    },
    spending_limit: limit_qty,
  }
}

pub fn test_context_input_01(output_ref, own_cs, token_value, datum) {
  Input {
    output_reference: output_ref,
    output: Output {
      address: Address(credential.ScriptCredential(own_cs), None),
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
      address: Address(credential.ScriptCredential(own_cs), None),
      value: value.add(
        minted_value,
        value.ada_policy_id,
        value.ada_asset_name,
        4_000_000,
      ),
      datum: InlineDatum(datum),
      reference_script: None,
    },
  }
}

// Create a UTxO
pub fn test_utxo_02(own_cs, token_value, datum) {
  Output {
    address: Address {
      payment_credential: ScriptCredential(own_cs),
      stake_credential: None,
    },
    value: token_value,
    datum: InlineDatum(datum),
    reference_script: None,
  }
}

pub fn test_user_utxo(pubkey_hash: ByteArray, token_value, datum) {
  Output {
    address: Address {
      payment_credential: credential.VerificationKeyCredential(pubkey_hash),
      stake_credential: None,
    },
    value: token_value,
    datum: InlineDatum(datum),
    reference_script: None,
  }
}

pub fn test_spend_script_context(
  output_ref,
  // can be one or many
  main_inputs,
  // can be one or many
  ref_inputs,
  // can be one or many
  main_outputs,
  // can be one or many
  minted_value,
  time_range,
  tx_hash: ByteArray,
) {
  ScriptContext {
    purpose: Spend(output_ref),
    transaction: Transaction {
      inputs: main_inputs,
      reference_inputs: ref_inputs,
      outputs: main_outputs,
      // fee: value.from_lovelace(2_000_000),
      fee: value.zero(),
      mint: value.to_minted_value(minted_value),
      certificates: [],
      withdrawals: [],
      validity_range: time_range,
      extra_signatories: [],
      redeemers: [],
      datums: dict.new(),
      id: TransactionId { hash: tx_hash },
    },
  }
}
