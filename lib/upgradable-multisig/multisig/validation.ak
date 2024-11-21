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
  signed_within_threshold, validate_multisig_datum,
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

  // Ensure this outref is spent in this transaction
  expect (own_input.output_reference == output_reference)?

  // Create a unique token name
  let sig_tkn_name =
    values.unique_token_name(
      output_reference.transaction_id.hash,
      output_reference.output_index,
      #"",
    )
  // Construct one Multisig token value 
  let multisig_value = value.from_asset(own_policy, sig_tkn_name, 1)

  // Extract and validate the datum from the output UTxO
  expect multisig_datum: MultisigDatum = data.output_datum(own_output)
  expect validate_multisig_datum(multisig_datum)?

  let output_lovelace = value.lovelace_of(own_output.value)

  // Verify that the output UTxO is sent to the correct script address
  let multisig_credential = credential.ScriptCredential(own_policy)

  // expect (own_output.address.payment_credential == multisig_credential)?
  and {
    // Verify that the correct token was minted
    (multisig_value == minted_tokens)?,
    // Verify that the output UTxO contains the multisig NFT
    (value.quantity_of(own_output.value, own_policy, sig_tkn_name) == 1)?,
    // Ensure that the output UTxO contains enough Lovelaces
    (output_lovelace >= multisig_datum.minimum_ada)?,
    // Verify that the output UTxO is sent to the correct script address
    (own_output.address.payment_credential == multisig_credential)?,
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

      expect output_datum: MultisigDatum = data.output_datum(own_output)
      let valid_multisig_datum = validate_multisig_datum(output_datum)

      let multisig_credential = credential.ScriptCredential(policy_id)

      let input_lovelace = value.lovelace_of(own_input.value)
      let output_lovelace = value.lovelace_of(own_output.value)
      let output_value_flat = value.flatten(own_output.value)
      let withdraw_amount = input_lovelace - output_lovelace

      let is_ada =
        datum.funds.policy_id == value.ada_policy_id && datum.funds.asset_name == value.ada_asset_name

      // Perform validations based on asset type
      let assets_valid =
        when is_ada is {
          True -> {
            expect list.length(output_value_flat) == 2
            expect input_lovelace >= output_lovelace
            // Ensure Lovelace amounts match expected transfer
            expect output_lovelace >= datum.minimum_ada
            True
          }
          False -> {
            expect list.length(output_value_flat) <= 3
            let input_payment =
              value.quantity_of(own_input.value, policy_id, asset_name)
            let output_payment =
              value.quantity_of(own_output.value, policy_id, asset_name)
            expect input_payment >= output_payment
            True
          }
        }
      and {
        // Validate presence of multisig NFT in the input
        valid_multisig_datum?,
        signed_within_threshold(datum, tx.extra_signatories)?,
        assets_valid?,
        // Check if the transfer adheres to the spending rules
        (withdraw_amount <= datum.spending_limit)?,
        // Validate that the datum is updated correctly
        (datum == output_datum)?,
        (own_output.address.payment_credential == multisig_credential)?,
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

      expect [(policy_id, _, 1)] = value.flatten(multisig_nft)
      // Extract and validate that the output datum is updated correctly
      expect output_datum: MultisigDatum = data.output_datum(own_output)
      let valid_multisig_datum = validate_multisig_datum(output_datum)

      let multisig_credential = credential.ScriptCredential(policy_id)

      and {
        valid_multisig_datum?,
        signed_within_threshold(datum, tx.extra_signatories)?,
        (own_output.value == own_input.value)?,
        // Verify that the output UTxO is sent back to the script address
        (own_output.address.payment_credential == multisig_credential)?,
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
