use aiken/cbor
use aiken/dict
use aiken/interval
use aiken/list
use aiken/transaction.{
  Input, NoDatum, Output, ScriptContext, Spend, Transaction, TransactionId,
}
use aiken/transaction/value.{Value}
use assist/data
use upgradable_multisig/tests
use upgradable_multisig/types.{
  AssetClass, MultisigDatum, MultisigRedeemer, Sign, Update,
}

// Ensure that no assets are lost in the transaction
fn value_preserved(input_value: Value, outputs: List<Output>) -> Bool {
  trace @"Input value:"
  trace cbor.diagnostic(input_value)
  trace @"Outputs:"
  trace cbor.diagnostic(outputs)

  // Sum up all the values from the outputs into a single Value
  let total_output_value =
    outputs
      |> list.foldl(
          value.zero(),
          fn(output, acc) { value.merge(acc, output.value) },
        )
  trace @"Total output value:"
  trace cbor.diagnostic(total_output_value)

  let flattened_input = value.flatten(input_value)
  trace @"Flattened input value:"
  trace cbor.diagnostic(flattened_input)

  // Compare each asset in the input to ensure it's preserved in the output
  flattened_input
    |> list.all(
        fn(asset) {
          let (policy_id, asset_name, qty) = asset
          let output_qty =
            value.quantity_of(total_output_value, policy_id, asset_name)
          trace @"Checking asset:"
          trace cbor.diagnostic((policy_id, asset_name, qty))
          trace @"Output quantity:"
          trace cbor.diagnostic(output_qty)
          output_qty >= qty
        },
      )
}

// Main validator function for the upgradable multisig contract
validator {
  fn multisig_validator(
    datum: MultisigDatum,
    redeemer: MultisigRedeemer,
    context: ScriptContext,
  ) -> Bool {
    let ScriptContext { transaction: tx, purpose } = context

    expect Spend(output_reference) = purpose

    let Transaction { inputs, outputs, extra_signatories, .. } = tx

    expect Some(own_input) = transaction.find_input(inputs, output_reference)

    // Count the number of valid signers for this transaction
    let matching_signers =
      list.filter(extra_signatories, fn(sig) { list.has(datum.signers, sig) })

    trace @"matching_signers"
    trace cbor.diagnostic(matching_signers)

    // Check if the number of valid signers meets or exceeds the threshold
    let signed_by_majority = list.length(matching_signers) >= datum.threshold

    trace @"signed_by_majority"
    trace cbor.diagnostic(signed_by_majority)
    trace @"datum.threshold"
    trace cbor.diagnostic(datum.threshold)

    // Perform common checks for both Sign and Update operations
    let common_checks =
      signed_by_majority? && value_preserved(own_input.output.value, outputs)?

    when redeemer is {
      Sign -> common_checks && validate_sign(datum, own_input, outputs)
      Update -> common_checks && validate_update(datum, own_input, outputs)
    }
  }
}

// Helper function to get the amount of a specific asset from a Value
fn get_asset_amount(value: Value, asset: AssetClass) -> Int {
  value.quantity_of(value, asset.policy_id, asset.asset_name)
}

fn validate_sign(
  datum: MultisigDatum,
  own_input: Input,
  outputs: List<Output>,
) -> Bool {
  expect [own_output, recipient_output, ..] = outputs

  trace @"own_output"
  trace cbor.diagnostic(own_output)
  trace @"recipient_output"
  trace cbor.diagnostic(recipient_output)

  let input_amount = get_asset_amount(own_input.output.value, datum.funds)
  let recipient_amount = get_asset_amount(recipient_output.value, datum.funds)
  let output_amount = get_asset_amount(own_output.value, datum.funds)
  let transfer_amount = input_amount - output_amount

  trace @"input_amount"
  trace cbor.diagnostic(input_amount)
  trace @"recipient_amount"
  trace cbor.diagnostic(recipient_amount)
  trace @"output_amount"
  trace cbor.diagnostic(output_amount)

  // Check if the transfer adheres to the spending rules
  if
  (input_amount != datum.funds_qty)? || (transfer_amount > datum.spending_limit)? || (recipient_amount != transfer_amount)?{
  
    False
  } else {
    // Validate that the datum is updated correctly
    expect output_datum: MultisigDatum = data.output_datum(own_output)
    is_datum_valid(datum, output_datum, output_amount)
  }
}

// Check if the output datum is valid 
fn is_datum_valid(
  datum_in: MultisigDatum,
  datum_out: MultisigDatum,
  output_amount: Int,
) -> Bool {
  let signers_valid = datum_out.signers == datum_in.signers
  let threshold_valid = datum_out.threshold == datum_in.threshold
  let asset_class_valid = datum_out.funds == datum_in.funds
  let output_quantity_valid = datum_out.funds_qty == output_amount
  trace @"datum_out.funds_qty"
  trace cbor.diagnostic(datum_out.funds_qty)
  trace @"output_amount"
  trace cbor.diagnostic(output_amount)

  let spend_limit_valid = datum_out.spending_limit == datum_in.spending_limit

  signers_valid? && threshold_valid? && asset_class_valid? && output_quantity_valid? && spend_limit_valid?
}

fn values_equal(a: Value, b: Value) -> Bool {
  value.is_zero(value.merge(a, value.negate(b)))
}

fn validate_update(
  input_datum: MultisigDatum,
  own_input: Input,
  outputs: List<Output>,
) -> Bool {
  expect [own_output, ..] = outputs

  // Validate that the output datum is updated correctly
  expect output_datum: MultisigDatum = data.output_datum(own_output)
  // Ensure the new signers list is not empty
  let new_signer_count = list.length(output_datum.signers)
  let old_signer_count = list.length(input_datum.signers)
  let signer_count_diff = new_signer_count - old_signer_count

  // Perform various checks on the new datum
  if
  (new_signer_count == 0)? || (output_datum.threshold <= 0)? || (output_datum.threshold > new_signer_count)? || (list.length(
    list.unique(output_datum.signers),
  ) != new_signer_count)? || (output_datum.funds_qty < 0)? || (output_datum.spending_limit <= 0)? || (output_datum.spending_limit > output_datum.funds_qty)? || (output_datum.funds_qty != get_asset_amount(
    own_output.value,
    output_datum.funds,
  ))?{
  
    False
  } else if signer_count_diff != 0 {
    // Handle signer addition or removal
    if signer_count_diff > 1 || signer_count_diff < -1 {
      False
    } else {
      // Ensure new threshold is appropriate and value is preserved
      //This ensures that the threshold is always at least a majority of the signers, 
      //preventing a situation where a minority could control the multisig.
      (output_datum.threshold >= new_signer_count / 2 + 1)? && values_equal(
        own_output.value,
        own_input.output.value,
      )
    }
  } else {
    // If signer count hasn't changed, ensure signers list is unchanged
    // This prevents swapping out a signer without changing the count
    (output_datum.signers == input_datum.signers)? && values_equal(
      own_output.value,
      own_input.output.value,
    )
  }
}

test success_sign() {
  // Set up test data
  let own_policy = tests.test_policy()
  let tx_hash = tests.test_224_01()
  let init_output_ref = tests.test_input_utxo_02(tx_hash)

  let redeemer = Sign

  // Create input and output UTxOs
  // let contract_total_value = 1_000_000_000_000
  let transaction_limit_value = 1_000_000_000

  // 100,000 ADA
  let input_value = 100_000_000_000
  // 99,000 ADA
  let output_value = 99_000_000_000
  // 1000 ADA
  let change_value = 1_000_000_000

  let pubkey_hash_01 = tests.test_224_02()
  let pubkey_hash_02 = tests.test_224_03()
  let pubkey_hash_03 = tests.test_224_04()
  let pubkey_hash_04 = tests.test_224_05()

  let signatories =
    [pubkey_hash_01, pubkey_hash_02, pubkey_hash_03, pubkey_hash_04]

  let threshold = list.length(signatories) / 2 + 1
  trace @"threshold"
  trace cbor.diagnostic(threshold)

  let datum =
    tests.test_multisig_datum(threshold, input_value, transaction_limit_value)

  let own_input =
    tests.test_context_input_01(
      init_output_ref,
      own_policy,
      value.from_lovelace(input_value),
      datum,
    )

  let output_datum =
    tests.test_multisig_datum(
      threshold,
      input_value - change_value,
      transaction_limit_value,
    )

  let own_output =
    tests.test_utxo_02(
      own_policy,
      value.from_lovelace(output_value),
      output_datum,
    )
  // let recipient_output = tests.test_utxo_02(own_policy, change_value, NoDatum)
  let recipient_output =
    tests.test_user_utxo(
      tests.test_withdraw_pkh(),
      value.from_lovelace(change_value),
      NoDatum,
    )

  // Create the transaction context
  let context =
    ScriptContext {
      purpose: Spend(own_input.output_reference),
      transaction: Transaction {
        inputs: [own_input],
        reference_inputs: [],
        outputs: [own_output, recipient_output],
        fee: value.zero(),
        mint: value.to_minted_value(value.zero()),
        certificates: [],
        withdrawals: [],
        validity_range: interval.everything(),
        extra_signatories: signatories,
        redeemers: [],
        datums: dict.new(),
        id: TransactionId { hash: tx_hash },
      },
    }

  trace @"test_recipient_output"
  trace cbor.diagnostic(recipient_output)
  trace @"test_output_value"
  trace cbor.diagnostic(output_value)

  // Call the validator function
  multisig_validator(datum, redeemer, context)
}

test success_update() {
  // Set up test data
  let own_policy = tests.test_policy()
  let tx_hash = tests.test_224_01()
  let init_output_ref = tests.test_input_utxo_02(tx_hash)

  let redeemer = Update

  // Create input and output UTxOs
  let input_value = 100_000_000_000

  // 100,000 ADA
  let pubkey_hash_01 = tests.test_224_02()
  let pubkey_hash_02 = tests.test_224_03()
  let pubkey_hash_03 = tests.test_224_04()
  let pubkey_hash_04 = tests.test_224_05()
  let pubkey_hash_05 = tests.test_224_06()

  // New signer
  let old_signatories =
    [pubkey_hash_01, pubkey_hash_02, pubkey_hash_03, pubkey_hash_04]
  let new_signatories =
    [pubkey_hash_01, pubkey_hash_02, pubkey_hash_03, pubkey_hash_05]

  // Updated list
  let old_threshold = list.length(old_signatories) / 2 + 1
  let new_threshold = list.length(new_signatories) / 2 + 1

  let old_spending_limit = 1_000_000_000
  // 1,000 ADA
  let new_spending_limit = 2_000_000_000

  // 2,000 ADA
  let old_datum =
    tests.test_multisig_datum(old_threshold, input_value, old_spending_limit)
  let new_datum =
    tests.test_multisig_datum(new_threshold, input_value, new_spending_limit)

  let own_input =
    tests.test_context_input_01(
      init_output_ref,
      own_policy,
      value.from_lovelace(input_value),
      old_datum,
    )

  let own_output =
    tests.test_utxo_02(
      own_policy,
      value.from_lovelace(input_value),
      // Same value as input
      new_datum,
    )

  // Create the transaction context
  let context =
    ScriptContext {
      purpose: Spend(own_input.output_reference),
      transaction: Transaction {
        inputs: [own_input],
        reference_inputs: [],
        outputs: [own_output],
        fee: value.zero(),
        mint: value.to_minted_value(value.zero()),
        certificates: [],
        withdrawals: [],
        validity_range: interval.everything(),
        extra_signatories: old_signatories,
        // Use old signatories for authorization
        redeemers: [],
        datums: dict.new(),
        id: TransactionId { hash: tx_hash },
      },
    }

  // Call the validator function
  multisig_validator(old_datum, redeemer, context)
}
