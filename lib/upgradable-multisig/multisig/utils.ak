use aiken/list
use aiken/transaction.{Input, Output}
use aiken/transaction/credential.{Credential}
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

  (signers_nr > 0)? && (datum.threshold > 0)? && (datum.spending_limit > 2_000_000)?
}

// Helper function to get the amount of a specific asset from a Value
pub fn get_asset_amount(value: Value, asset: AssetClass) -> Int {
  value.quantity_of(value, asset.policy_id, asset.asset_name)
}

// Helper function to validate where the NFT goes
pub fn validate_token_output(
  output: Output,
  policy: PolicyId,
  token_name: ByteArray,
  credential: Credential,
) -> Bool {
  // is_credential: Bool,
  let token_quantity = value.quantity_of(output.value, policy, token_name)
  let payment_credential = output.address.payment_credential

  token_quantity == 1 && payment_credential == credential
}

pub fn signed_within_threshold(
  datum: MultisigDatum,
  extra_signatories: List<PubKeyHash>,
) -> Bool {
  let signer_count_length =
    list.foldr(
      extra_signatories,
      0,
      fn(current_signer, accumulator) -> Int {
        if list.has(datum.signers, current_signer) {
          accumulator + 1
        } else {
          accumulator
        }
      },
    )

  and {
    signer_count_length >= datum.threshold,
    True,
  }
}
