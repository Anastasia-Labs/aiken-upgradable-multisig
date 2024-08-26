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

    // Check that there are no more inputs in the same address.
    expect Some(own_input) = transaction.find_input(inputs, output_reference)
    let script_credential = own_input.output.address.payment_credential

    // Filter inputs by the same script address
    let script_inputs =
      list.filter(
        inputs,
        fn(input) {
          input.output.address.payment_credential == script_credential
        },
      )

    // Ensure there's exactly one script input
    expect list.length(script_inputs) == 1

    // Count the number of valid signers for this transaction
    let matching_signers =
      list.filter(extra_signatories, fn(sig) { list.has(datum.signers, sig) })

    // trace @"extra_signatories"
    // trace cbor.diagnostic(list.length(extra_signatories))
    // trace @"matching_signers"
    // trace cbor.diagnostic(matching_signers)
    // Check if the number of valid signers meets or exceeds the threshold
    let signed_within_threshold =
      list.length(matching_signers) >= datum.threshold

    // trace @"signed_within_threshold"
    // trace cbor.diagnostic(signed_within_threshold)
    // trace @"datum.threshold"
    // trace cbor.diagnostic(datum.threshold)
    when redeemer is {
      Sign ->
        signed_within_threshold? && validate_sign(datum, own_input, outputs)
      Update ->
        signed_within_threshold? && validate_update(datum, own_input, outputs)
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
  expect [own_output, ..] = outputs

  // trace @"own_output"
  // trace cbor.diagnostic(own_output)
  let input_amount = get_asset_amount(own_input.output.value, datum.funds)
  let output_amount = get_asset_amount(own_output.value, datum.funds)
  let transfer_amount = input_amount - output_amount

  // trace @"input_amount"
  // trace cbor.diagnostic(input_amount)
  // trace @"output_amount"
  // trace cbor.diagnostic(output_amount)
  expect output_datum: MultisigDatum = data.output_datum(own_output)

  and {
    // Check if the transfer adheres to the spending rules
    (transfer_amount <= datum.spending_limit)?,
    // Validate that the datum is updated correctly
    datum_is_valid(datum, output_datum)?,
  }
}

// Check if the output datum is valid 
fn datum_is_valid(datum_in: MultisigDatum, datum_out: MultisigDatum) -> Bool {
  let signers_valid = datum_out.signers == datum_in.signers
  let threshold_valid = datum_out.threshold == datum_in.threshold
  let asset_class_valid = datum_out.funds == datum_in.funds

  // trace @"output_amount"
  // trace cbor.diagnostic(output_amount)
  let spend_limit_valid = datum_out.spending_limit == datum_in.spending_limit

  signers_valid? && threshold_valid? && asset_class_valid? && spend_limit_valid?
}

fn validate_update(
  _input_datum: MultisigDatum,
  own_input: Input,
  outputs: List<Output>,
) -> Bool {
  expect [own_output, ..] = outputs

  // Validate that the output datum is updated correctly
  expect output_datum: MultisigDatum = data.output_datum(own_output)
  // Ensure the new signers list is not empty
  let new_signer_count = list.length(output_datum.signers)

  // Perform various checks on the new datum
  and {
    (new_signer_count > 0)?,
    (output_datum.threshold > 0)?,
    (output_datum.threshold <= new_signer_count)?,
    (list.length(list.unique(output_datum.signers)) == new_signer_count)?,
    (output_datum.spending_limit > 0)?,
    (own_output.value == own_input.output.value)?,
  }
}

test success_sign() {
  // Set up test data
  let own_policy = tests.test_policy()
  let tx_hash = tests.test_224_01()
  let init_output_ref = tests.test_input_utxo_02(tx_hash)

  let redeemer = Sign

  // Create input and output UTxOs
  let transaction_limit_value = 1_000_000_000

  // 100,000 ADA
  let contract_value = 100_000_000_000
  // 99,000 ADA
  let output_value = 99_000_000_000
  // 1000 ADA
  let withdrawal_value = 1_000_000_000

  let pubkey_hash_01 = tests.test_224_02()
  let pubkey_hash_02 = tests.test_224_03()
  let pubkey_hash_03 = tests.test_224_04()
  let pubkey_hash_04 = tests.test_224_05()

  let signatories =
    [pubkey_hash_01, pubkey_hash_02, pubkey_hash_03, pubkey_hash_04]

  let threshold = list.length(signatories) / 2 + 1

  let datum =
    tests.test_multisig_datum(signatories, threshold, transaction_limit_value)

  let own_input =
    tests.test_context_input_01(
      init_output_ref,
      own_policy,
      value.from_lovelace(contract_value),
      datum,
    )

  let output_datum =
    tests.test_multisig_datum(signatories, threshold, transaction_limit_value)

  let own_output =
    tests.test_utxo_02(
      own_policy,
      value.from_lovelace(output_value),
      output_datum,
    )
  // let recipient_output = tests.test_utxo_02(own_policy, withdrawal_value, NoDatum)
  let recipient_output =
    tests.test_user_utxo(
      tests.test_withdraw_pkh(),
      value.from_lovelace(withdrawal_value),
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

  trace @"Total Signitories"
  trace cbor.diagnostic(list.length(signatories))
  trace @"Threshold"
  trace cbor.diagnostic(threshold)
  trace @"Actual Signitories"
  trace cbor.diagnostic(
    list.length([pubkey_hash_01, pubkey_hash_02, pubkey_hash_03]),
  )
  trace @"Contract Amount"
  trace cbor.diagnostic(contract_value)
  trace @"Spending limit"
  trace cbor.diagnostic(transaction_limit_value)
  trace @"Withdrawal Asset Output Amount"
  trace cbor.diagnostic(withdrawal_value)
  trace @"Contract Asset Output Amount"
  trace cbor.diagnostic(output_value)

  // Call the validator function
  multisig_validator(datum, redeemer, context)
}

test reject_insufficient_signatures() {
  // Set up test data
  let own_policy = tests.test_policy()
  let tx_hash = tests.test_224_01()
  let init_output_ref = tests.test_input_utxo_02(tx_hash)

  let redeemer = Sign

  // Create input and output UTxOs
  let transaction_limit_value = 1_000_000_000

  // 100,000 ADA
  let contract_value = 100_000_000_000
  // 99,000 ADA
  let output_value = 99_000_000_000
  // 1000 ADA
  let withdrawal_value = 1_000_000_000

  let pubkey_hash_01 = tests.test_224_02()
  let pubkey_hash_02 = tests.test_224_03()

  let pubkey_hash_03 = tests.test_224_04()
  let pubkey_hash_04 = tests.test_224_05()
  let signatories =
    [pubkey_hash_01, pubkey_hash_02, pubkey_hash_03, pubkey_hash_04]

  let threshold = list.length(signatories) / 2 + 1

  // trace @"threshold"
  // trace cbor.diagnostic(threshold)
  let datum =
    tests.test_multisig_datum(signatories, threshold, transaction_limit_value)

  let own_input =
    tests.test_context_input_01(
      init_output_ref,
      own_policy,
      value.from_lovelace(contract_value),
      datum,
    )

  let output_datum =
    tests.test_multisig_datum(signatories, threshold, transaction_limit_value)

  let own_output =
    tests.test_utxo_02(
      own_policy,
      value.from_lovelace(output_value),
      output_datum,
    )
  // let recipient_output = tests.test_utxo_02(own_policy, withdrawal_value, NoDatum)
  let recipient_output =
    tests.test_user_utxo(
      tests.test_withdraw_pkh(),
      value.from_lovelace(withdrawal_value),
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
        extra_signatories: [pubkey_hash_01, pubkey_hash_02],
        redeemers: [],
        datums: dict.new(),
        id: TransactionId { hash: tx_hash },
      },
    }

  trace @"Total Signitories"
  trace cbor.diagnostic(list.length(signatories))
  trace @"Threshold"
  trace cbor.diagnostic(threshold)
  trace @"Actual Signitories"
  trace cbor.diagnostic(list.length([pubkey_hash_01, pubkey_hash_02]))
  trace @"Contract Amount"
  trace cbor.diagnostic(contract_value)
  trace @"Spending limit"
  trace cbor.diagnostic(transaction_limit_value)
  trace @"Withdrawal Asset Output Amount"
  trace cbor.diagnostic(withdrawal_value)
  trace @"Contract Asset Output Amount"
  trace cbor.diagnostic(output_value)

  // Call the validator function
  !multisig_validator(datum, redeemer, context)
}

// test success_update() {
//   // Set up test data
//   let own_policy = tests.test_policy()
//   let tx_hash = tests.test_224_01()
//   let init_output_ref = tests.test_input_utxo_02(tx_hash)

//   let redeemer = Update

//   // Create input and output UTxOs
//   let contract_value = 100_000_000_000

//   // 100,000 ADA
//   let pubkey_hash_01 = tests.test_224_02()
//   let pubkey_hash_02 = tests.test_224_03()
//   let pubkey_hash_03 = tests.test_224_04()
//   let pubkey_hash_04 = tests.test_224_05()
//   let pubkey_hash_05 = tests.test_224_06()

//   // New signer
//   let old_signatories =
//     [pubkey_hash_01, pubkey_hash_02, pubkey_hash_03, pubkey_hash_04]
//   let new_signatories =
//     [pubkey_hash_01, pubkey_hash_02, pubkey_hash_03, pubkey_hash_05]

//   // Updated list
//   let old_threshold = list.length(old_signatories) / 2 + 1
//   let new_threshold = list.length(new_signatories) / 2 + 1

//   let old_spending_limit = 1_000_000_000
//   // 1,000 ADA
//   let new_spending_limit = 2_000_000_000

//   // 2,000 ADA
//   let old_datum =
//     tests.test_multisig_datum(
//       old_signatories,
//       old_threshold,
//       old_spending_limit,
//     )
//   let new_datum =
//     tests.test_multisig_datum(
//       new_signatories,
//       new_threshold,
//       new_spending_limit,
//     )

//   let own_input =
//     tests.test_context_input_01(
//       init_output_ref,
//       own_policy,
//       value.from_lovelace(contract_value),
//       old_datum,
//     )

//   let own_output =
//     tests.test_utxo_02(
//       own_policy,
//       value.from_lovelace(contract_value),
//       // Same value as input
//       new_datum,
//     )

//   // Create the transaction context
//   let context =
//     ScriptContext {
//       purpose: Spend(own_input.output_reference),
//       transaction: Transaction {
//         inputs: [own_input],
//         reference_inputs: [],
//         outputs: [own_output],
//         fee: value.zero(),
//         mint: value.to_minted_value(value.zero()),
//         certificates: [],
//         withdrawals: [],
//         validity_range: interval.everything(),
//         extra_signatories: old_signatories,
//         // Use old signatories for authorization
//         redeemers: [],
//         datums: dict.new(),
//         id: TransactionId { hash: tx_hash },
//       },
//     }

//   trace @"Old Signitories"
//   trace cbor.diagnostic(list.length(old_signatories))
//   trace @"New Signitories"
//   trace cbor.diagnostic(list.length(new_signatories))
//   trace @"Old Threshold"
//   trace cbor.diagnostic(old_threshold)
//   trace @"New Threshold"
//   trace cbor.diagnostic(new_threshold)
//   trace @"Actual Signitories"
//   trace cbor.diagnostic(list.length(old_signatories))
//   trace @"Contract Amount"
//   trace cbor.diagnostic(contract_value)
//   trace @"Old Spending limit"
//   trace cbor.diagnostic(old_spending_limit)
//   trace @"New Spending limit"
//   trace cbor.diagnostic(new_spending_limit)
//   trace @"Contract Asset Output Amount"
//   trace cbor.diagnostic(contract_value)
//   // Call the validator function
//   multisig_validator(old_datum, redeemer, context)
// }

test success_adjust_threshold() {
  // Set up test data
  let own_policy = tests.test_policy()
  let tx_hash = tests.test_224_01()
  let init_output_ref = tests.test_input_utxo_02(tx_hash)

  let redeemer = Update

  // Create input and output UTxOs
  let contract_value = 100_000_000_000

  let pubkey_hash_01 = tests.test_224_02()
  let pubkey_hash_02 = tests.test_224_03()
  let pubkey_hash_03 = tests.test_224_04()
  let pubkey_hash_04 = tests.test_224_05()

  let signatories =
    [pubkey_hash_01, pubkey_hash_02, pubkey_hash_03, pubkey_hash_04]

  let old_threshold = 2
  let new_threshold = 3

  let spending_limit = 1_000_000_000

  let old_datum =
    tests.test_multisig_datum(signatories, old_threshold, spending_limit)
  let new_datum =
    tests.test_multisig_datum(signatories, new_threshold, spending_limit)

  let own_input =
    tests.test_context_input_01(
      init_output_ref,
      own_policy,
      value.from_lovelace(contract_value),
      old_datum,
    )

  let own_output =
    tests.test_utxo_02(
      own_policy,
      value.from_lovelace(contract_value),
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
        extra_signatories: signatories,
        redeemers: [],
        datums: dict.new(),
        id: TransactionId { hash: tx_hash },
      },
    }

  trace @"Old Threshold"
  trace cbor.diagnostic(old_threshold)
  trace @"New Threshold"
  trace cbor.diagnostic(new_threshold)

  // Call the validator function
  multisig_validator(old_datum, redeemer, context)
}

test success_add_signer() {
  // Set up test data
  let own_policy = tests.test_policy()
  let tx_hash = tests.test_224_01()
  let init_output_ref = tests.test_input_utxo_02(tx_hash)

  let redeemer = Update

  // Create input and output UTxOs
  let contract_value = 100_000_000_000

  let pubkey_hash_01 = tests.test_224_02()
  let pubkey_hash_02 = tests.test_224_03()
  let pubkey_hash_03 = tests.test_224_04()
  let pubkey_hash_04 = tests.test_224_05()
  let new_pubkey_hash = tests.test_224_06()

  let old_signatories =
    [pubkey_hash_01, pubkey_hash_02, pubkey_hash_03, pubkey_hash_04]
  let new_signatories =
    [
      pubkey_hash_01,
      pubkey_hash_02,
      pubkey_hash_03,
      pubkey_hash_04,
      new_pubkey_hash,
    ]

  let threshold = 3
  let spending_limit = 1_000_000_000

  let old_datum =
    tests.test_multisig_datum(old_signatories, threshold, spending_limit)
  let new_datum =
    tests.test_multisig_datum(new_signatories, threshold, spending_limit)

  let own_input =
    tests.test_context_input_01(
      init_output_ref,
      own_policy,
      value.from_lovelace(contract_value),
      old_datum,
    )

  let own_output =
    tests.test_utxo_02(
      own_policy,
      value.from_lovelace(contract_value),
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
        redeemers: [],
        datums: dict.new(),
        id: TransactionId { hash: tx_hash },
      },
    }

  trace @"Old Signatories Count"
  trace cbor.diagnostic(list.length(old_signatories))
  trace @"New Signatories Count"
  trace cbor.diagnostic(list.length(new_signatories))

  // Call the validator function
  multisig_validator(old_datum, redeemer, context)
}

test success_remove_signer() {
  // Set up test data
  let own_policy = tests.test_policy()
  let tx_hash = tests.test_224_01()
  let init_output_ref = tests.test_input_utxo_02(tx_hash)

  let redeemer = Update

  // Create input and output UTxOs
  let contract_value = 100_000_000_000

  let pubkey_hash_01 = tests.test_224_02()
  let pubkey_hash_02 = tests.test_224_03()
  let pubkey_hash_03 = tests.test_224_04()
  let pubkey_hash_04 = tests.test_224_05()

  let old_signatories =
    [pubkey_hash_01, pubkey_hash_02, pubkey_hash_03, pubkey_hash_04]
  let new_signatories =
    [pubkey_hash_01, pubkey_hash_02, pubkey_hash_03]

  let old_threshold = 3
  let new_threshold = 2
  // Adjust threshold to maintain validity
  let spending_limit = 1_000_000_000

  let old_datum =
    tests.test_multisig_datum(old_signatories, old_threshold, spending_limit)
  let new_datum =
    tests.test_multisig_datum(new_signatories, new_threshold, spending_limit)

  let own_input =
    tests.test_context_input_01(
      init_output_ref,
      own_policy,
      value.from_lovelace(contract_value),
      old_datum,
    )

  let own_output =
    tests.test_utxo_02(
      own_policy,
      value.from_lovelace(contract_value),
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
        redeemers: [],
        datums: dict.new(),
        id: TransactionId { hash: tx_hash },
      },
    }

  trace @"Old Signatories Count"
  trace cbor.diagnostic(list.length(old_signatories))
  trace @"New Signatories Count"
  trace cbor.diagnostic(list.length(new_signatories))
  trace @"Old Threshold"
  trace cbor.diagnostic(old_threshold)
  trace @"New Threshold"
  trace cbor.diagnostic(new_threshold)

  // Call the validator function
  multisig_validator(old_datum, redeemer, context)
}
