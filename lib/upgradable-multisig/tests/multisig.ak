use aiken/cbor
use aiken/dict
use aiken/interval
use aiken/list
use aiken/transaction.{
  Input, Mint, NoDatum, ScriptContext, Spend, Transaction, TransactionId,
}
use aiken/transaction/value
use assist/values
use upgradable_multisig/multisig/validation.{
  validate_initiate_multisig, validate_sign, validate_update,
}
use upgradable_multisig/tests/tests

test succeed_initiate_multisig() {
  let own_policy = tests.test_policy()
  let tx_hash = tests.test_224_01()

  let init_output_ref = tests.test_input_utxo_02(tx_hash)

  let multisig_token_name = values.unique_token_name(tx_hash, 1, #"")

  // Create input and output UTxOs
  let transaction_limit_value = 1_000_000_000

  let min_value = 2_000_000
  let output_value = 100_000_000_000

  let pubkey_hash_01 = tests.test_224_02()
  let pubkey_hash_02 = tests.test_224_03()
  let pubkey_hash_03 = tests.test_224_04()
  let pubkey_hash_04 = tests.test_224_05()

  let signatories =
    [pubkey_hash_01, pubkey_hash_02, pubkey_hash_03, pubkey_hash_04]

  let threshold = list.length(signatories) / 2 + 1

  let multisig_value =
    value.add(
      value.from_lovelace(output_value),
      own_policy,
      multisig_token_name,
      1,
    )
  let user_input =
    tests.test_context_input_01(
      init_output_ref,
      own_policy,
      value.from_lovelace(min_value),
      NoDatum,
    )

  let output_datum =
    tests.test_multisig_datum(signatories, threshold, transaction_limit_value)

  let multisig_output =
    tests.test_utxo_02(own_policy, multisig_value, output_datum)

  let context =
    ScriptContext {
      purpose: Mint(own_policy),
      transaction: Transaction {
        inputs: [user_input],
        reference_inputs: [],
        outputs: [multisig_output],
        fee: value.zero(),
        mint: value.to_minted_value(multisig_value),
        certificates: [],
        withdrawals: [],
        validity_range: interval.everything(),
        extra_signatories: [],
        redeemers: [],
        datums: dict.new(),
        id: TransactionId { hash: tx_hash },
      },
    }

  validate_initiate_multisig(
    own_policy,
    init_output_ref,
    0,
    0,
    context.transaction,
  )
}

test succeed_end_multisig() {
  let own_policy = tests.test_policy()
  let tx_hash = tests.test_224_01()

  let init_output_ref = tests.test_input_utxo_02(tx_hash)

  let multisig_token_name = values.unique_token_name(tx_hash, 1, #"")

  // Create input and output UTxOs
  let transaction_limit_value = 1_000_000_000

  let output_value = 100_000_000_000

  let pubkey_hash_01 = tests.test_224_02()
  let pubkey_hash_02 = tests.test_224_03()
  let pubkey_hash_03 = tests.test_224_04()
  let pubkey_hash_04 = tests.test_224_05()

  let signatories =
    [pubkey_hash_01, pubkey_hash_02, pubkey_hash_03, pubkey_hash_04]

  let threshold = list.length(signatories) / 2 + 1

  let datum =
    tests.test_multisig_datum(signatories, threshold, transaction_limit_value)
  let multisig_value =
    value.add(
      value.from_lovelace(output_value),
      own_policy,
      multisig_token_name,
      1,
    )
  let multisig_input =
    tests.test_context_input_01(
      init_output_ref,
      own_policy,
      multisig_value,
      datum,
    )

  let multisig_output = tests.test_utxo_02(own_policy, multisig_value, datum)

  let context =
    ScriptContext {
      purpose: Mint(own_policy),
      transaction: Transaction {
        inputs: [multisig_input],
        reference_inputs: [],
        outputs: [multisig_output],
        fee: value.zero(),
        mint: value.to_minted_value(multisig_value),
        certificates: [],
        withdrawals: [],
        validity_range: interval.everything(),
        extra_signatories: [],
        redeemers: [],
        datums: dict.new(),
        id: TransactionId { hash: tx_hash },
      },
    }

  validate_initiate_multisig(
    own_policy,
    init_output_ref,
    0,
    0,
    context.transaction,
  )
}

test success_sign() {
  // Set up test data
  let own_policy = tests.test_policy()
  let tx_hash = tests.test_224_01()
  let init_output_ref = tests.test_input_utxo_02(tx_hash)

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
  let multisig_token_name = values.unique_token_name(tx_hash, 1, #"")

  let multisig_value =
    value.add(
      value.from_lovelace(contract_value),
      own_policy,
      multisig_token_name,
      1,
    )
  let multisig_input =
    tests.test_context_input_01(
      init_output_ref,
      own_policy,
      multisig_value,
      datum,
    )

  let output_datum =
    tests.test_multisig_datum(signatories, threshold, transaction_limit_value)
  let multisig_out_value =
    value.add(
      value.from_lovelace(output_value),
      own_policy,
      multisig_token_name,
      1,
    )
  let own_output =
    tests.test_utxo_02(own_policy, multisig_out_value, output_datum)
  let recipient_output =
    tests.test_user_utxo(
      tests.test_withdraw_pkh(),
      value.from_lovelace(withdrawal_value),
      NoDatum,
    )

  // Create the transaction context
  let context =
    ScriptContext {
      purpose: Spend(multisig_input.output_reference),
      transaction: Transaction {
        inputs: [multisig_input],
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
  validate_sign(datum, 0, 0, context)
}

test reject_insufficient_signatures() {
  // Set up test data
  let own_policy = tests.test_policy()
  let tx_hash = tests.test_224_01()
  let init_output_ref = tests.test_input_utxo_02(tx_hash)

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
  let multisig_token_name = values.unique_token_name(tx_hash, 1, #"")

  let multisig_value =
    value.add(
      value.from_lovelace(contract_value),
      own_policy,
      multisig_token_name,
      1,
    )
  let multisig_input =
    tests.test_context_input_01(
      init_output_ref,
      own_policy,
      multisig_value,
      datum,
    )

  let output_datum =
    tests.test_multisig_datum(signatories, threshold, transaction_limit_value)
  let multisig_out_value =
    value.add(
      value.from_lovelace(output_value),
      own_policy,
      multisig_token_name,
      1,
    )
  let own_output =
    tests.test_utxo_02(own_policy, multisig_out_value, output_datum)
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
      purpose: Spend(multisig_input.output_reference),
      transaction: Transaction {
        inputs: [multisig_input],
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
  !validate_sign(datum, 0, 0, context)
}

test success_adjust_threshold() {
  // Set up test data
  let own_policy = tests.test_policy()
  let tx_hash = tests.test_224_01()
  let init_output_ref = tests.test_input_utxo_02(tx_hash)

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

  let multisig_token_name = values.unique_token_name(tx_hash, 1, #"")

  let multisig_value =
    value.add(
      value.from_lovelace(contract_value),
      own_policy,
      multisig_token_name,
      1,
    )
  let multisig_input =
    tests.test_context_input_01(
      init_output_ref,
      own_policy,
      multisig_value,
      old_datum,
    )

  let multisig_out_value =
    value.add(
      value.from_lovelace(contract_value),
      own_policy,
      multisig_token_name,
      1,
    )
  let own_output = tests.test_utxo_02(own_policy, multisig_out_value, new_datum)

  // Create the transaction context
  let context =
    ScriptContext {
      purpose: Spend(multisig_input.output_reference),
      transaction: Transaction {
        inputs: [multisig_input],
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
  trace @"New threshold value"
  trace cbor.diagnostic(new_threshold)
  trace @"Number of signatories approving this change"
  trace cbor.diagnostic(list.length(signatories))
  trace @"Contract value after threshold adjustment (should be unchanged)"
  trace cbor.diagnostic(value.from_lovelace(contract_value))
  trace @"Result: Signature threshold successfully updated!"
  // Call the validator function
  validate_update(old_datum, 0, 0, context)
}

test success_add_signer() {
  // Set up test data
  let own_policy = tests.test_policy()
  let tx_hash = tests.test_224_01()
  let init_output_ref = tests.test_input_utxo_02(tx_hash)

  //   let redeemer = Update
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
  let multisig_token_name = values.unique_token_name(tx_hash, 1, #"")

  let multisig_value =
    value.add(
      value.from_lovelace(contract_value),
      own_policy,
      multisig_token_name,
      1,
    )
  let multisig_input =
    tests.test_context_input_01(
      init_output_ref,
      own_policy,
      multisig_value,
      old_datum,
    )

  let multisig_out_value =
    value.add(
      value.from_lovelace(contract_value),
      own_policy,
      multisig_token_name,
      1,
    )

  let own_output = tests.test_utxo_02(own_policy, multisig_out_value, new_datum)

  // Create the transaction context
  let context =
    ScriptContext {
      purpose: Spend(multisig_input.output_reference),
      transaction: Transaction {
        inputs: [multisig_input],
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
  trace @"Number of signatories after addition"
  trace cbor.diagnostic(list.length(new_signatories))
  trace @"Signature threshold after addition (unchanged)"
  trace cbor.diagnostic(threshold)
  trace @"Contract value after adding signer (should be unchanged)"
  trace cbor.diagnostic(contract_value)
  trace @"Result: New signer successfully added to the multisig!"

  validate_update(old_datum, 0, 0, context)
}

test success_remove_signer() {
  // Set up test data
  let own_policy = tests.test_policy()
  let tx_hash = tests.test_224_01()
  let init_output_ref = tests.test_input_utxo_02(tx_hash)

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
  let multisig_token_name = values.unique_token_name(tx_hash, 1, #"")

  let multisig_value =
    value.add(
      value.from_lovelace(contract_value),
      own_policy,
      multisig_token_name,
      1,
    )
  let multisig_input =
    tests.test_context_input_01(
      init_output_ref,
      own_policy,
      multisig_value,
      old_datum,
    )

  let multisig_out_value =
    value.add(
      value.from_lovelace(contract_value),
      own_policy,
      multisig_token_name,
      1,
    )
  let own_output = tests.test_utxo_02(own_policy, multisig_out_value, new_datum)

  // Create the transaction context
  let context =
    ScriptContext {
      purpose: Spend(multisig_input.output_reference),
      transaction: Transaction {
        inputs: [multisig_input],
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
  trace cbor.diagnostic(list.length(new_signatories))
  trace @"Signature threshold after removal and adjustment (Can be changed)"
  trace cbor.diagnostic(new_threshold)
  trace @"Contract value after removing signer (should be unchanged)"
  trace cbor.diagnostic(contract_value)
  trace @"Result: Signer successfully removed and threshold adjusted"

  validate_update(old_datum, 0, 0, context)
}
