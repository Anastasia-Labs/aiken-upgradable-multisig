use aiken/list
use aiken/transaction/value.{Value}
use upgradable_multisig/types.{AssetClass, MultisigDatum, PubKeyHash}

// Helper function to get the amount of a specific asset from a Value
pub fn get_asset_amount(value: Value, asset: AssetClass) -> Int {
  value.quantity_of(value, asset.policy_id, asset.asset_name)
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
