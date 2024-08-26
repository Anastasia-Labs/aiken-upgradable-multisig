use aiken/bytearray
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

    // Check if the number of valid signers meets or exceeds the threshold
    let signed_within_threshold =
      list.length(matching_signers) >= datum.threshold

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

  let input_amount = get_asset_amount(own_input.output.value, datum.funds)
  let output_amount = get_asset_amount(own_output.value, datum.funds)
  let transfer_amount = input_amount - output_amount

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

  trace @"Test: Successful Transaction Signing"
  trace @"Total number of signatories in the multisig"
  trace cbor.diagnostic(list.length(signatories))
  trace @"Required threshold of signatures"
  trace cbor.diagnostic(threshold)
  trace @"Number of signatories actually signing this transaction"
  trace cbor.diagnostic(
    list.length([pubkey_hash_01, pubkey_hash_02, pubkey_hash_03]),
  )
  trace @"Total amount in the contract (in lovelace)"
  trace cbor.diagnostic(contract_value)
  trace @"Maximum spending limit per transaction (in lovelace)"
  trace cbor.diagnostic(transaction_limit_value)
  trace @"Amount being withdrawn in this transaction (in lovelace)"
  trace cbor.diagnostic(withdrawal_value)
  trace @"Remaining amount in the contract after withdrawal (in lovelace)"
  trace cbor.diagnostic(output_value)
  trace @"Result: Transaction successfully signed and executed!"

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

  trace @"Test: Rejecting Transaction with Insufficient Signatures"
  trace @"Total number of signatories in the multisig"
  trace cbor.diagnostic(list.length(signatories))
  trace @"Required threshold of signatures"
  trace cbor.diagnostic(threshold)
  trace @"Number of signatories actually signing this transaction"
  trace cbor.diagnostic(list.length([pubkey_hash_01, pubkey_hash_02]))
  trace @"Total amount in the contract (in lovelace)"
  trace cbor.diagnostic(contract_value)
  trace @"Maximum spending limit per transaction (in lovelace)"
  trace cbor.diagnostic(transaction_limit_value)
  trace @"Attempted withdrawal amount (in lovelace)"
  trace cbor.diagnostic(withdrawal_value)
  trace @"Contract amount if withdrawal were allowed (in lovelace)"
  trace cbor.diagnostic(output_value)
  trace @"Result: Transaction rejected due to insufficient signatures!"

  // Call the validator function
  !multisig_validator(datum, redeemer, context)
}

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

  trace @"Test: Successfully Adjusting Signature Threshold"
  trace @"Original signature threshold"
  trace cbor.diagnostic(old_threshold)
  trace @"Total number of signatories in the multisig"
  trace cbor.diagnostic(list.length(signatories))
  trace @"Current contract value (in lovelace)"
  trace cbor.diagnostic(value.from_lovelace(contract_value))
  trace @"User clicks on action Redeemer: Update"
  trace cbor.diagnostic(redeemer)
  trace @"New threshold value"
  trace cbor.diagnostic(new_threshold)
  trace @"Number of signatories approving this change"
  trace cbor.diagnostic(list.length(signatories))
  trace @"Contract value after threshold adjustment (should be unchanged)"
  trace cbor.diagnostic(value.from_lovelace(contract_value))
  trace @"Result: Signature threshold successfully updated!"
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

  trace @"Test: Successfully Adding a New Signer to the Multisig Contract"
  trace @"Number of signatories before addition"
  trace cbor.diagnostic(list.length(old_signatories))
  trace @"Current contract value (in lovelace)"
  trace cbor.diagnostic(contract_value)
  trace @"Current signature threshold"
  trace cbor.diagnostic(threshold)
  trace @"Number of signatories approving this change"
  trace cbor.diagnostic(list.length(old_signatories))
  trace @"Redeemer used for this operation"
  trace cbor.diagnostic(redeemer)
  trace @"Number of signatories after addition"
  trace cbor.diagnostic(list.length(new_signatories))
  trace @"Signature threshold after addition (unchanged)"
  trace cbor.diagnostic(threshold)
  trace @"Contract value after adding signer (should be unchanged)"
  trace cbor.diagnostic(contract_value)
  trace @"Result: New signer successfully added to the multisig!"

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

  trace @"Test: Successfully Removing a Signer from the Multisig Contract"
  trace @"Current contract value (in lovelace)"
  trace cbor.diagnostic(contract_value)
  trace @"Number of signatories before removal"
  trace cbor.diagnostic(list.length(old_signatories))
  trace @"Signature threshold before removal"
  trace cbor.diagnostic(old_threshold)
  trace @"Number of signatories approving this change"
  trace cbor.diagnostic(list.length(old_signatories))
  trace @"Redeemer used for this operation"
  trace cbor.diagnostic(redeemer)
  trace @"Number of signatories after removal"
  trace cbor.diagnostic(list.length(new_signatories))
  trace @"Signature threshold after removal and adjustment (Can be changed)"
  trace cbor.diagnostic(new_threshold)
  trace @"Contract value after removing signer (should be unchanged)"
  trace cbor.diagnostic(contract_value)
  trace @"Result: Signer successfully removed and threshold adjusted"

  multisig_validator(old_datum, redeemer, context)
}
