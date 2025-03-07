use aiken/collection/dict
use aiken/collection/list
use aiken_design_patterns/singular_utxo_indexer
use cardano/address.{Address, Script}
use cardano/assets.{PolicyId, Value, quantity_of, tokens}
use cardano/transaction.{
  InlineDatum, Input, Output, OutputReference, Transaction,
}
use upgradable_multisig/multisig/utils.{
  multisig_token_name, signed_within_threshold, validate_multisig_datum,
}
use upgradable_multisig/types.{MultisigDatum}

pub fn validate_initiate_multisig(
  own_policy: PolicyId,
  output_index: Int,
  minted_value: Value,
  outputs: List<Output>,
) -> Bool {
  expect Some(Output {
    address: output_address,
    datum: InlineDatum(output_datum),
    value: output_value,
    ..
  }) = list.at(outputs, output_index)

  let address_correct = output_address.payment_credential == Script(own_policy)

  expect [Pair(tkn, 1)] = dict.to_pairs(tokens(minted_value, own_policy))
  let minted_token_correct = tkn == multisig_token_name
  let output_value_has_token =
    quantity_of(output_value, own_policy, multisig_token_name) == 1

  expect multisig_datum: MultisigDatum = output_datum
  let datum_correct = validate_multisig_datum(multisig_datum)

  and {
    address_correct?,
    datum_correct?,
    output_value_has_token?,
    minted_token_correct?,
  }
}

pub fn validate_multisig_end(own_policy: PolicyId, minted_value: Value) -> Bool {
  expect [Pair(tkn, -1)] = dict.to_pairs(tokens(minted_value, own_policy))
  tkn == multisig_token_name
}

pub fn validate_sign(
  datum: MultisigDatum,
  own_ref: OutputReference,
  input_index: Int,
  output_index: Int,
  tx: Transaction,
) -> Bool {
  singular_utxo_indexer.spend(
    validation_logic: fn(_in_idx, own_input, _redeemer, _out_ix, own_output) {
      expect Input {
        output: Output {
          address: Address {
            payment_credential: Script(own_policy) as in_credential,
            ..
          },
          value: in_value,
          ..
        },
        ..
      } = own_input
      expect Output {
        address: Address { payment_credential: out_credential, .. },
        datum: InlineDatum(out_datum),
        value: out_value,
        ..
      } = own_output

      let enough_signers = signed_within_threshold(datum, tx.extra_signatories)
      let out_address_correct = out_credential == in_credential
      expect output_datum: MultisigDatum = out_datum
      let out_datum_correct = output_datum == datum

      let in_token_correct =
        quantity_of(in_value, own_policy, multisig_token_name) == 1
      let out_token_correct =
        quantity_of(out_value, own_policy, multisig_token_name) == 1

      let in_funds =
        quantity_of(in_value, datum.fund_policy_id, datum.fund_asset_name)
      let out_funds =
        quantity_of(out_value, datum.fund_policy_id, datum.fund_asset_name)
      let spending_limit_followed = in_funds - out_funds <= datum.spending_limit

      and {
        enough_signers?,
        out_address_correct?,
        out_datum_correct?,
        in_token_correct?,
        out_token_correct?,
        spending_limit_followed?,
      }
    },
    redeemer: Void,
    input_index: input_index,
    output_index: output_index,
    own_ref: own_ref,
    tx: tx,
  )
}

pub fn validate_update(
  datum: MultisigDatum,
  own_ref: OutputReference,
  input_index: Int,
  output_index: Int,
  tx: Transaction,
) -> Bool {
  singular_utxo_indexer.spend(
    validation_logic: fn(_in_idx, own_input, _redeemer, _out_ix, own_output) {
      expect Input {
        output: Output {
          address: Address {
            payment_credential: Script(own_policy) as in_credential,
            ..
          },
          value: in_value,
          ..
        },
        ..
      } = own_input
      expect Output {
        address: Address { payment_credential: out_credential, .. },
        datum: InlineDatum(out_datum),
        value: out_value,
        ..
      } = own_output

      let enough_signers = signed_within_threshold(datum, tx.extra_signatories)
      let out_address_correct = out_credential == in_credential

      expect updated_datum: MultisigDatum = out_datum
      let out_datum_correct =
        updated_datum.fund_policy_id == datum.fund_policy_id && updated_datum.fund_asset_name == datum.fund_asset_name

      let in_token_correct =
        quantity_of(in_value, own_policy, multisig_token_name) == 1
      let out_value_unchanged = out_value == in_value

      and {
        enough_signers?,
        out_address_correct?,
        out_datum_correct?,
        in_token_correct?,
        out_value_unchanged?,
      }
    },
    redeemer: Void,
    input_index: input_index,
    output_index: output_index,
    own_ref: own_ref,
    tx: tx,
  )
}

pub fn validate_remove(
  datum: MultisigDatum,
  own_ref: OutputReference,
  input_index: Int,
  tx: Transaction,
) -> Bool {
  let Transaction { inputs, extra_signatories, mint, .. } = tx

  expect Some(Input {
    output_reference: in_ref,
    output: Output {
      address: Address { payment_credential: Script(own_policy), .. },
      value: in_val,
      ..
    },
  }) = inputs |> list.at(input_index)

  let reference_correct = own_ref == in_ref
  let enough_signers = signed_within_threshold(datum, extra_signatories)

  let token_correct = quantity_of(in_val, own_policy, multisig_token_name) == 1
  let token_destroyed = quantity_of(mint, own_policy, multisig_token_name) == -1

  and {
    reference_correct?,
    enough_signers?,
    token_correct?,
    token_destroyed?,
  }
}
