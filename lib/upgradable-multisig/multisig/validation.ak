use aiken/list
use aiken/transaction.{
  Input, Output, OutputReference, ScriptContext, Transaction,
}
use aiken/transaction/credential
use aiken/transaction/value.{PolicyId, from_minted_value}
use aiken_design_patterns/singular_utxo_indexer as singular_utxo_indexer
use assist/data
use assist/values
use upgradable_multisig/multisig/utils.{
  get_asset_amount, output_assets_valid, signed_within_threshold,
  validate_multisig_datum,
}
use upgradable_multisig/types.{MultisigDatum}

pub fn validate_initiate_multisig(
  own_policy: PolicyId,
  output_reference: OutputReference,
  input_index: Int,
  tx: Transaction,
) -> Bool {
  let minted_tokens = tx.mint |> from_minted_value()
  expect Some(own_input) = list.at(tx.inputs, input_index)
  expect [own_output, ..] = tx.outputs

  let multisig_credential = credential.ScriptCredential(own_policy)
  // Ensure this outref is spent in this transaction
  let is_outref_spent = own_input.output_reference == output_reference

  // Extract datums
  expect multisig_datum: MultisigDatum = data.output_datum(own_output)

  // Check if the managed asset is ADA
  // Create a unique token name
  let sig_tkn_name =
    values.unique_token_name(
      output_reference.transaction_id.hash,
      output_reference.output_index,
      #"",
    )
  // Construct one Multisig token value 
  let multisig_value = value.from_asset(own_policy, sig_tkn_name, 1)

  let payment_credential = own_output.address.payment_credential
  and {
    is_outref_spent?,
    output_assets_valid(
      own_input.output,
      own_output,
      multisig_datum,
      own_policy,
      sig_tkn_name,
    )?,
    (payment_credential == multisig_credential)?,
    (multisig_value == minted_tokens)?,
  }
}

pub fn validate_multisig_end(
  own_policy: PolicyId,
  contract_input_index: Int,
  tx: Transaction,
) -> Bool {
  expect Some(contract_input) = list.at(tx.inputs, contract_input_index)

  let minted_token = tx.mint |> from_minted_value()
  // Extract the multisig NFT
  let multisig_nft =
    contract_input.output.value |> value.without_lovelace() |> value.flatten()

  expect [(multisig_policy, multisig_token_name, 1)] = multisig_nft

  // Get the tokens being burned) in this transaction
  expect [(pid, tkn, amt)] = value.flatten(minted_token)
  expect multisig_datum: MultisigDatum = data.input_datum(contract_input)
  let valid_multisig_datum = validate_multisig_datum(multisig_datum)

  // Verify all conditions are met
  and {
    signed_within_threshold(multisig_datum, tx.extra_signatories)?,
    valid_multisig_datum?,
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
      // Verify the inputs contain 1 Multisig NFT Asset
      let multisig_nft =
        own_input.value
          |> value.without_lovelace()

      expect [(policy_id, asset_name, 1)] = value.flatten(multisig_nft)

      let input_amount = get_asset_amount(own_input.value, datum.funds)
      let output_amount = get_asset_amount(own_output.value, datum.funds)
      let withdraw_amount = input_amount - output_amount
      expect output_datum: MultisigDatum = data.output_datum(own_output)
      let valid_multisig_datum = validate_multisig_datum(output_datum)

      let multisig_credential = credential.ScriptCredential(policy_id)
      let payment_credential = own_output.address.payment_credential

      and {
        // Validate presence of multisig NFT in the input
        output_assets_valid(
          own_input,
          own_output,
          output_datum,
          policy_id,
          asset_name,
        )?,
        (payment_credential == multisig_credential)?,
        valid_multisig_datum?,
        signed_within_threshold(datum, tx.extra_signatories)?,
        // Check if the transfer adheres to the spending rules
        (withdraw_amount <= datum.spending_limit)?,
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
      // Verify the inputs contain 1 Multisig NFT Asset
      let multisig_nft =
        own_input.value
          |> value.without_lovelace()

      expect [(policy_id, asset_name, 1)] = value.flatten(multisig_nft)
      // Validate that the output datum is updated correctly
      expect output_datum: MultisigDatum = data.output_datum(own_output)
      // Ensure the new signers list is not empty
      let new_signer_count = list.length(output_datum.signers)
      let valid_multisig_datum = validate_multisig_datum(output_datum)

      let multisig_credential = credential.ScriptCredential(policy_id)
      let payment_credential = own_output.address.payment_credential

      // Perform various checks on the new datum
      and {
        valid_multisig_datum?,
        signed_within_threshold(datum, tx.extra_signatories)?,
        (list.length(list.unique(output_datum.signers)) == new_signer_count)?,
        (own_output.value == own_input.value)?,
        output_assets_valid(
          own_input,
          own_output,
          output_datum,
          policy_id,
          asset_name,
        )?,
        (payment_credential == multisig_credential)?,
      }
    },
    (input_index, output_index),
    ctx,
  )
}

pub fn validate_remove(
  datum: MultisigDatum,
  input_index: Int,
  output_index: Int,
  ctx: ScriptContext,
) -> Bool {
  let ScriptContext { transaction: tx, .. } = ctx

  singular_utxo_indexer.spend(
    fn(own_input, _own_output) {
      let multisig_nft =
        own_input.value
          |> value.without_lovelace()

      let minted_value = value.from_minted_value(tx.mint)

      // Extract and validate the AccountDatum
      expect [(policy_id, multisig_asset_name, 1)] = value.flatten(multisig_nft)
      let valid_multisig_datum = validate_multisig_datum(datum)

      and {
        // Validate the Datum has valid multisig inputs.
        valid_multisig_datum?,
        // Check that the reference NFT is burned
        (value.quantity_of(minted_value, policy_id, multisig_asset_name) == -1)?,
        // Ensure no output contains the multisig NFT
        list.all(
          tx.outputs,
          fn(output) {
            value.quantity_of(output.value, policy_id, multisig_asset_name) == 0
          },
        )?,
      }
    },
    (input_index, output_index),
    ctx,
  )
}
