use aiken/cbor
use aiken/collection/list
use aiken_design_patterns/singular_utxo_indexer as singular_utxo_indexer
use cardano/address.{Script}
use cardano/assets.{
  PolicyId, ada_asset_name, ada_policy_id, flatten, from_asset, lovelace_of,
  quantity_of, without_lovelace,
}
use cardano/transaction.{
  InlineDatum, Input, Output, OutputReference, Transaction,
}
use cardano/value
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
  // let minted_tokens = tx.mint |> assets.from_asset

  expect Some(in_utxo) = list.at(tx.inputs, input_index)
  expect Some(out_utxo) = list.at(tx.outputs, output_reference.output_index)

  // expect [out_utxo, ..] = tx.outputs
  // Ensure this outref is spent in this transaction
  expect (in_utxo.output_reference == output_reference)?

  let personal_tag = "MultisigNFT"

  // Create a unique token name
  let sig_tkn_name =
    value.unique_token_name(
      output_reference.transaction_id,
      output_reference.output_index,
      #"",
      personal_tag,
    )

  // Construct one Multisig token value 
  let multisig_value = from_asset(own_policy, sig_tkn_name, 1)

  // Extract and validate the datum from the output UTxO
  expect InlineDatum(out_utxo_inline_datum) = out_utxo.datum
  expect multisig_datum: MultisigDatum = out_utxo_inline_datum
  expect validate_multisig_datum(multisig_datum)?

  let output_lovelace = lovelace_of(out_utxo.value)

  // Verify that the output UTxO is sent to the correct script address
  let multisig_credential = Script(own_policy)

  trace @"multisig_value"
  trace cbor.diagnostic(multisig_value)
  trace @"tx.mint"
  trace cbor.diagnostic(tx.mint)
  and {
    // Verify that the correct token was minted
    (multisig_value == tx.mint)?,
    // Verify that the output UTxO contains the multisig NFT
    (quantity_of(out_utxo.value, own_policy, sig_tkn_name) == 1)?,
    // Ensure that the output UTxO contains enough Lovelaces
    (output_lovelace >= multisig_datum.minimum_ada)?,
    // Verify that the output UTxO is sent to the correct script address
    (out_utxo.address.payment_credential == multisig_credential)?,
  }
}

pub fn validate_multisig_end(
  own_policy: PolicyId,
  contract_input_index: Int,
  tx: Transaction,
) -> Bool {
  expect Some(contract_input) = list.at(tx.inputs, contract_input_index)

  let minted_token = tx.mint
  // Extract the multisig NFT
  let multisig_nft =
    contract_input.output.value |> without_lovelace() |> flatten()

  expect [(multisig_policy, multisig_token_name, 1)] = multisig_nft

  // Get the tokens being burned) in this transaction
  expect [(pid, tkn, amt)] = flatten(minted_token)

  expect InlineDatum(contract_input_inline_datum) = contract_input.output.datum
  expect multisig_datum: MultisigDatum = contract_input_inline_datum

  // expect multisig_datum: MultisigDatum = data.input_datum()
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
  datum: Option<MultisigDatum>,
  redeemer: Pair<Int, Int>,
  output_reference: OutputReference,
  tx: Transaction,
) -> Bool {
  singular_utxo_indexer.spend(
    fn(_input_index, in_utxo, _redeemer, _output_index, out_utxo) {
      // Verify the inputs contain 1 Multisig NFT Asset
      let multisig_nft =
        in_utxo.output.value
          |> without_lovelace()

      expect [(policy_id, asset_name, 1)] = flatten(multisig_nft)

      expect Some(option_datum) = datum
      expect InlineDatum(out_utxo_inline_datum) = out_utxo.datum
      expect output_datum: MultisigDatum = out_utxo_inline_datum

      let valid_multisig_datum = validate_multisig_datum(output_datum)

      let multisig_credential = Script(policy_id)
      let input_lovelace = lovelace_of(in_utxo.output.value)
      let output_lovelace = lovelace_of(out_utxo.value)
      let output_value_flat = flatten(out_utxo.value)
      let withdraw_amount = input_lovelace - output_lovelace

      let is_ada =
        option_datum.funds.policy_id == ada_policy_id && option_datum.funds.asset_name == ada_asset_name

      // Perform validations based on asset type
      let assets_valid =
        when is_ada is {
          True -> {
            expect list.length(output_value_flat) == 2
            expect input_lovelace >= output_lovelace
            // Ensure Lovelace amounts match expected transfer
            expect output_lovelace >= option_datum.minimum_ada
            True
          }
          False -> {
            expect list.length(output_value_flat) <= 3
            let input_payment =
              quantity_of(in_utxo.output.value, policy_id, asset_name)
            let output_payment =
              quantity_of(out_utxo.value, policy_id, asset_name)
            expect input_payment >= output_payment
            True
          }
        }
      and {
        // Validate presence of multisig NFT in the input
        valid_multisig_datum?,
        signed_within_threshold(option_datum, tx.extra_signatories)?,
        assets_valid?,
        // Check if the transfer adheres to the spending rules
        (withdraw_amount <= option_datum.spending_limit)?,
        // Validate that the datum is updated correctly
        (option_datum == output_datum)?,
        (out_utxo.address.payment_credential == multisig_credential)?,
      }
    },
    redeemer,
    redeemer,
    output_reference,
    tx,
  )
}

pub fn validate_update(
  datum: Option<MultisigDatum>,
  redeemer: Pair<Int, Int>,
  output_reference: OutputReference,
  tx: Transaction,
) -> Bool {
  singular_utxo_indexer.spend(
    fn(_input_index, in_utxo, _redeemer, _output_index, out_utxo) {
      // Verify the inputs contain 1 Multisig NFT Asset
      let multisig_nft =
        in_utxo.output.value
          |> without_lovelace()

      expect [(policy_id, _, 1)] = flatten(multisig_nft)
      // Extract and validate that the output datum is updated correctly
      expect Some(option_datum) = datum
      expect InlineDatum(out_utxo_inline_datum) = out_utxo.datum
      expect output_datum: MultisigDatum = out_utxo_inline_datum

      // expect output_datum: MultisigDatum = data.output_datum(out_utxo)
      let valid_multisig_datum = validate_multisig_datum(output_datum)

      let multisig_credential = Script(policy_id)

      and {
        valid_multisig_datum?,
        signed_within_threshold(option_datum, tx.extra_signatories)?,
        (out_utxo.value == in_utxo.output.value)?,
        // Verify that the output UTxO is sent back to the script address
        (out_utxo.address.payment_credential == multisig_credential)?,
      }
    },
    redeemer,
    redeemer,
    output_reference,
    tx,
  )
}

pub fn validate_remove(
  datum: Option<MultisigDatum>,
  redeemer: Pair<Int, Int>,
  output_reference: OutputReference,
  tx: Transaction,
) -> Bool {
  singular_utxo_indexer.spend(
    fn(_input_index, in_utxo, _redeemer, _output_index, _out_utxo) {
      let multisig_nft =
        in_utxo.output.value
          |> without_lovelace()

      let minted_value = tx.mint

      // Extract and validate the AccountDatum
      expect [(policy_id, multisig_asset_name, 1)] = flatten(multisig_nft)
      expect Some(option_datum) = datum
      let valid_multisig_datum = validate_multisig_datum(option_datum)

      and {
        // Validate the Datum has valid multisig inputs.
        valid_multisig_datum?,
        // Check that the reference NFT is burned
        (quantity_of(minted_value, policy_id, multisig_asset_name) == -1)?,
        // Ensure no output contains the multisig NFT
        list.all(
          tx.outputs,
          fn(output) {
            quantity_of(output.value, policy_id, multisig_asset_name) == 0
          },
        )?,
      }
    },
    redeemer,
    redeemer,
    output_reference,
    tx,
  )
}
