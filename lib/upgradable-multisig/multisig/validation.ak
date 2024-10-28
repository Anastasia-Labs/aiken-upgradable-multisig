use aiken/list
use aiken/transaction.{Output, OutputReference, ScriptContext, Transaction}
use aiken/transaction/credential
use aiken/transaction/value.{PolicyId, from_minted_value}
use aiken_design_patterns/singular_utxo_indexer as singular_utxo_indexer
use assist/data
use assist/values
use upgradable_multisig/multisig/utils.{
  get_asset_amount, signed_within_threshold, validate_multisig_datum,
  validate_token_output,
}
use upgradable_multisig/types.{MultisigDatum}

pub fn validate_initiate_multisig(
  own_policy: PolicyId,
  output_reference: OutputReference,
  input_index: Int,
  output_index: Int,
  tx: Transaction,
) -> Bool {
  let minted_tokens = tx.mint |> from_minted_value()
  expect Some(own_input) = list.at(tx.inputs, input_index)
  expect Some(own_output) = list.at(tx.outputs, output_index)
  let multisig_credential = credential.ScriptCredential(own_policy)
  // Ensure this outref is spent in this transaction
  let is_outref_spent = own_input.output_reference == output_reference

  // expect [multisig_output, ..] = tx.outputs
  // Extract datums
  expect multisig_datum: MultisigDatum = data.output_datum(own_output)

  // Create a unique token name
  let sig_tkn_name =
    values.unique_token_name(
      output_reference.transaction_id.hash,
      output_reference.output_index,
      #"",
    )
  // Construct one Multisig token value 
  let multisig_value = value.from_asset(own_policy, sig_tkn_name, 1)

  // Validate internal consistency of multisig datum
  let valid_multisig_datum = validate_multisig_datum(multisig_datum)

  // Ensure token output goes back to the script
  let multisig_token_to_script =
    validate_token_output(
      own_output,
      own_policy,
      sig_tkn_name,
      multisig_credential,
    )

  and {
    is_outref_spent?,
    valid_multisig_datum?,
    (multisig_value == minted_tokens)?,
    multisig_token_to_script?,
  }
}

pub fn validate_multisig_end(
  datum: MultisigDatum,
  own_policy: PolicyId,
  contract_input_index: Int,
  tx: Transaction,
) -> Bool {
  expect Some(contract_input) = list.at(tx.inputs, contract_input_index)
  let minted_token = tx.mint |> from_minted_value()

  // Extract the multisig NFT
  let multisig_nft =
    contract_input.output.value |> value.without_lovelace() |> value.flatten()

  expect [(multisig_policy, multisig_token_name, _)] = multisig_nft

  // Get the tokens being minted (or burned) in this transaction
  expect [(pid, tkn, amt)] = value.flatten(minted_token)

  // Verify all conditions are met
  and {
    signed_within_threshold(datum, tx.extra_signatories)?,
    (value.quantity_of(
      contract_input.output.value,
      multisig_policy,
      multisig_token_name,
    ) == 1)?,
    // The token in the input must be from our policy
    (multisig_policy == own_policy)?,
    // The token being burned must be from our policy
    (pid == own_policy)?,
    // The token name being burned must match the one from the input
    (tkn == multisig_token_name)?,
    // Exactly one token must be burned (negative amount)
    (amt == -1)?,
  }
}

pub fn validate_sign(
  datum: MultisigDatum,
  input_index: Int,
  output_index: Int,
  ctx: ScriptContext,
) -> Bool {
  let ScriptContext { transaction: tx, .. } = ctx

  singular_utxo_indexer.spend(
    fn(own_input, own_output) {
      // Verify the inputs contain 1 Service NFT Asset
      let multisig_nft =
        own_input.value
          |> value.without_lovelace()

      expect [(policy_id, asset_name, _)] = value.flatten(multisig_nft)

      let input_amount = get_asset_amount(own_input.value, datum.funds)
      let output_amount = get_asset_amount(own_output.value, datum.funds)
      let transfer_amount = input_amount - output_amount
      expect output_datum: MultisigDatum = data.output_datum(own_output)
      and {
        // Validate presence of multisig NFT in the input
        (value.quantity_of(own_input.value, policy_id, asset_name) == 1)?,
        signed_within_threshold(datum, tx.extra_signatories)?,
        // Check if the transfer adheres to the spending rules
        (transfer_amount <= datum.spending_limit)?,
        // Validate that the datum is updated correctly
        (datum == output_datum)?,
        // Validate presence of multisig NFT in the output
        (value.quantity_of(own_output.value, policy_id, asset_name) == 1)?,
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
      // Verify the inputs contain 1 Service NFT Asset
      let multisig_nft =
        own_input.value
          |> value.without_lovelace()

      expect [(policy_id, asset_name, _)] = value.flatten(multisig_nft)
      // Validate that the output datum is updated correctly
      expect output_datum: MultisigDatum = data.output_datum(own_output)
      // Ensure the new signers list is not empty
      let new_signer_count = list.length(output_datum.signers)

      // Perform various checks on the new datum
      and {
        (value.quantity_of(own_input.value, policy_id, asset_name) == 1)?,
        signed_within_threshold(datum, tx.extra_signatories)?,
        (new_signer_count > 0)?,
        (output_datum.threshold > 0)?,
        (output_datum.threshold <= new_signer_count)?,
        (list.length(list.unique(output_datum.signers)) == new_signer_count)?,
        (output_datum.spending_limit > 0)?,
        (own_output.value == own_input.value)?,
        (value.quantity_of(own_output.value, policy_id, asset_name) == 1)?,
      }
    },
    (input_index, output_index),
    ctx,
  )
}
