use aiken/collection/dict
use aiken/collection/list
use aiken_design_patterns/singular_utxo_indexer
use cardano/address.{Address, Script}
use cardano/assets.{PolicyId, quantity_of, tokens}
use cardano/transaction.{
  InlineDatum, Input, Output, OutputReference, Transaction,
}
use upgradable_multisig/multisig/utils.{
  signed_within_threshold, validate_multisig_datum,
}
use upgradable_multisig/types.{MultisigDatum}

pub fn validate_init(
  own_policy: PolicyId,
  own_ref: OutputReference,
  output_index: Int,
  tx: Transaction,
) -> Bool {
  let Transaction { outputs, mint, extra_signatories, .. } = tx

  expect Some(Output {
    address: output_address,
    datum: InlineDatum(output_datum),
    value: output_value,
    ..
  }) = list.at(outputs, output_index)

  let address_correct = output_address.payment_credential == Script(own_policy)

  let multisig_token_name = utils.multisig_token_name(own_ref)

  expect [Pair(tkn, 1)] = dict.to_pairs(tokens(mint, own_policy))
  let minted_token_correct = tkn == multisig_token_name
  let output_value_has_token =
    quantity_of(output_value, own_policy, multisig_token_name) == 1

  expect multisig_datum: MultisigDatum = output_datum
  let datum_correct = validate_multisig_datum(multisig_datum, extra_signatories)

  and {
    address_correct?,
    datum_correct?,
    output_value_has_token?,
    minted_token_correct?,
  }
}

pub fn validate_end(
  own_policy: PolicyId,
  input_index: Int,
  tx: Transaction,
) -> Bool {
  expect Some(contract_input) = list.at(tx.inputs, input_index)

  let sig_token = assets.tokens(contract_input.output.value, own_policy)
  expect [Pair(multisig_token_name, 1)] = dict.to_pairs(sig_token)

  expect [Pair(tkn, amt)] = dict.to_pairs(tokens(tx.mint, own_policy))

  (tkn == multisig_token_name)? && (amt == -1)?
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

      let sig_token = assets.tokens(in_value, own_policy)
      expect [Pair(multisig_token_name, 1)] = dict.to_pairs(sig_token)

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
  let Transaction { extra_signatories, .. } = tx
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

      let enough_signers = signed_within_threshold(datum, extra_signatories)
      let out_address_correct = out_credential == in_credential

      expect updated_datum: MultisigDatum = out_datum
      let out_datum_correct =
        updated_datum.fund_policy_id == datum.fund_policy_id && updated_datum.fund_asset_name == datum.fund_asset_name && validate_multisig_datum(
          updated_datum,
          extra_signatories,
        )

      let sig_token = assets.tokens(in_value, own_policy)
      expect [Pair(multisig_token_name, 1)] = dict.to_pairs(sig_token)

      let in_token_correct =
        quantity_of(in_value, own_policy, multisig_token_name) == 1

      expect [Pair(_, out_ada), ..out_tl] =
        out_value |> assets.to_dict |> dict.to_pairs
      expect [Pair(_, in_ada), ..in_tl] =
        in_value |> assets.to_dict |> dict.to_pairs
      // Add without lovelace in check.
      let out_value_unchanged = out_tl == in_tl
      expect [Pair(_, out_amount), ..] = dict.to_pairs(out_ada)
      expect [Pair(_, in_amount), ..] = dict.to_pairs(in_ada)

      let out_ada_correct = out_amount >= in_amount

      let own_outputs =
        list.filter(
          tx.outputs,
          fn(out) {
            when
              (out.address.payment_credential, out.address.stake_credential)
            is {
              (Script(policy), None) -> policy == own_policy
              _ -> False
            }
          },
        )
      let single_output = list.length(own_outputs) == 1

      and {
        enough_signers?,
        out_address_correct?,
        out_datum_correct?,
        in_token_correct?,
        out_value_unchanged?,
        out_ada_correct?,
        single_output?,
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
      value: in_value,
      ..
    },
  }) = inputs |> list.at(input_index)

  let reference_correct = own_ref == in_ref
  let enough_signers = signed_within_threshold(datum, extra_signatories)

  let sig_token = assets.tokens(in_value, own_policy)
  expect [Pair(multisig_token_name, 1)] = dict.to_pairs(sig_token)

  let token_correct =
    quantity_of(in_value, own_policy, multisig_token_name) == 1
  let token_destroyed = quantity_of(mint, own_policy, multisig_token_name) == -1

  and {
    reference_correct?,
    enough_signers?,
    token_correct?,
    token_destroyed?,
  }
}
