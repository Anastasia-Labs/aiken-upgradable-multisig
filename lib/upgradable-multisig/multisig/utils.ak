use aiken/list
use aiken/transaction.{Input, Output}
use aiken/transaction/value.{PolicyId, Value}
use upgradable_multisig/types.{AssetClass, MultisigDatum, PubKeyHash}

pub fn get_input_by_token(
  inputs: List<Input>,
  policy_id: PolicyId,
  token_name: ByteArray,
) -> Option<Input> {
  list.find(
    inputs,
    fn(input) {
      value.quantity_of(input.output.value, policy_id, token_name) > 0
    },
  )
}

pub fn validate_multisig_datum(datum: MultisigDatum) -> Bool {
  let signers_nr = list.length(datum.signers)
  (signers_nr >= datum.threshold)? && (datum.threshold > 0)? && (datum.spending_limit > 2_000_000)?
}

// Helper function to get the amount of a specific asset from a Value
pub fn get_asset_amount(value: Value, asset: AssetClass) -> Int {
  value.quantity_of(value, asset.policy_id, asset.asset_name)
}

pub fn output_assets_valid(
  out_input: Output,
  output: Output,
  datum: MultisigDatum,
  policy_id: PolicyId,
  token_name: ByteArray,
) -> Bool {
  let input_lovelace = value.lovelace_of(out_input.value)
  let output_lovelace = value.lovelace_of(output.value)
  let output_value_flat = value.flatten(output.value)

  let is_ada =
    datum.funds.policy_id == value.ada_policy_id && datum.funds.asset_name == value.ada_asset_name

  let assets_valid =
    when is_ada is {
      True -> {
        expect list.length(output_value_flat) == 2
        expect input_lovelace >= output_lovelace
        // Ensure Lovelace amounts match expected transfer
        expect output_lovelace > datum.minimum_ada
        True
      }
      False -> {
        expect list.length(output_value_flat) <= 3
        let input_payment =
          value.quantity_of(out_input.value, policy_id, token_name)
        let output_payment =
          value.quantity_of(output.value, policy_id, token_name)
        expect input_payment == output_payment
        True
      }
    }
  assets_valid
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
