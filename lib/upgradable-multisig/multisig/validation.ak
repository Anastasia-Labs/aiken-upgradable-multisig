use aiken/list
use aiken/transaction.{Output, ScriptContext, Transaction}
use aiken_design_patterns/singular_utxo_indexer as singular_utxo_indexer
use assist/data
use upgradable_multisig/multisig/utils.{
  get_asset_amount, signed_within_threshold,
}
use upgradable_multisig/types.{MultisigDatum}

pub fn validate_sign(
  datum: MultisigDatum,
  input_index: Int,
  output_index: Int,
  ctx: ScriptContext,
) -> Bool {
  let ScriptContext { transaction: tx, .. } = ctx

  singular_utxo_indexer.spend(
    fn(own_input, own_output) {
      let input_amount = get_asset_amount(own_input.value, datum.funds)
      let output_amount = get_asset_amount(own_output.value, datum.funds)
      let transfer_amount = input_amount - output_amount
      expect output_datum: MultisigDatum = data.output_datum(own_output)
      and {
        signed_within_threshold(datum, tx.extra_signatories)?,
        // Check if the transfer adheres to the spending rules
        (transfer_amount <= datum.spending_limit)?,
        // Validate that the datum is updated correctly
        (datum == output_datum)?,
      }
    },
    (input_index, output_index),
    ctx,
  )
}

pub fn validate_update(
  datum: MultisigDatum,
  input_index: Int,
  output_index: Int,
  ctx: ScriptContext,
) -> Bool {
  let ScriptContext { transaction: tx, .. } = ctx

  singular_utxo_indexer.spend(
    fn(own_input, own_output) {
      // Validate that the output datum is updated correctly
      expect output_datum: MultisigDatum = data.output_datum(own_output)
      // Ensure the new signers list is not empty
      let new_signer_count = list.length(output_datum.signers)

      // Perform various checks on the new datum
      and {
        signed_within_threshold(datum, tx.extra_signatories)?,
        (new_signer_count > 0)?,
        (output_datum.threshold > 0)?,
        (output_datum.threshold <= new_signer_count)?,
        (list.length(list.unique(output_datum.signers)) == new_signer_count)?,
        (output_datum.spending_limit > 0)?,
        (own_output.value == own_input.value)?,
      }
    },
    (input_index, output_index),
    ctx,
  )
}
