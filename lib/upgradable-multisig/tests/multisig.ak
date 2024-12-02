use aiken/cbor
use aiken/collection/dict
use aiken/collection/list
use aiken/interval
use cardano/assets.{add, from_lovelace, zero}
use cardano/script_context.{Minting, ScriptContext, Spending}
use cardano/transaction.{NoDatum, Transaction}
use cardano/value
use upgradable_multisig/multisig/validation.{
  validate_initiate_multisig, validate_multisig_end, validate_remove,
  validate_sign, validate_update,
}
use upgradable_multisig/tests/tests
use upgradable_multisig/types.{EndMultiSig, InitMultiSig, Remove, Sign, Update}

test succeed_initiate_multisig() {
  let own_policy = tests.test_policy()
  let tx_hash = tests.test_224_01()

  let init_output_ref = tests.test_input_utxo_02(tx_hash)

  let personal_tag = "MultisigNFT"

  let multisig_token_name =
    value.unique_token_name(
      init_output_ref.transaction_id,
      init_output_ref.output_index,
      #"",
      personal_tag,
    )

  // Create input and output UTxOs
  let transaction_limit_value = 1_000_000_000

  let contract_value = 100_000_000_000

  let pubkey_hash_01 = tests.test_224_02()
  let pubkey_hash_02 = tests.test_224_03()
  let pubkey_hash_03 = tests.test_224_04()
  let pubkey_hash_04 = tests.test_224_05()

  let signatories =
    [pubkey_hash_01, pubkey_hash_02, pubkey_hash_03, pubkey_hash_04]

  let threshold = list.length(signatories) / 2 + 1

  let user_input =
    tests.test_context_input_01(
      init_output_ref,
      own_policy,
      from_lovelace(contract_value),
      NoDatum,
    )

  let multisig_out_value = add(zero, own_policy, multisig_token_name, 1)

  let output_datum =
    tests.test_multisig_datum(signatories, threshold, transaction_limit_value)

  let multisig_output =
    tests.test_utxo_02(
      own_policy,
      multisig_out_value,
      contract_value,
      output_datum,
    )

  let context =
    ScriptContext {
      transaction: Transaction {
        inputs: [user_input],
        reference_inputs: [],
        outputs: [multisig_output],
        fee: 0,
        mint: multisig_out_value,
        certificates: [],
        withdrawals: [],
        validity_range: interval.everything,
        extra_signatories: signatories,
        redeemers: [],
        datums: dict.empty,
        id: tx_hash,
        votes: [],
        proposal_procedures: [],
        current_treasury_amount: None,
        treasury_donation: None,
      },
      redeemer: InitMultiSig {
        output_reference: init_output_ref,
        input_index: 0,
      },
      // Added the missing 'redeemer' field
      info: Minting(own_policy),
    }

  validate_initiate_multisig(
    own_policy,
    init_output_ref,
    0,
    context.transaction,
  )
}

test succeed_end_multisig() {
  let own_policy = tests.test_policy()
  let tx_hash = tests.test_224_01()

  let init_output_ref = tests.test_input_utxo_02(tx_hash)

  let multisig_token_name = value.unique_token_name(tx_hash, 1, #"", "")

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
  let multisig_value = add(zero, own_policy, multisig_token_name, 1)
  let multisig_input =
    tests.test_context_input_01(
      init_output_ref,
      own_policy,
      multisig_value,
      datum,
    )

  let multisig_out_value = add(zero, own_policy, multisig_token_name, -1)
  let multisig_output =
    tests.test_utxo_02(own_policy, multisig_out_value, output_value, datum)

  let context =
    ScriptContext {
      transaction: Transaction {
        inputs: [multisig_input],
        reference_inputs: [],
        outputs: [multisig_output],
        fee: 0,
        mint: multisig_out_value,
        certificates: [],
        withdrawals: [],
        validity_range: interval.everything,
        extra_signatories: signatories,
        redeemers: [],
        datums: dict.empty,
        id: tx_hash,
        votes: [],
        proposal_procedures: [],
        current_treasury_amount: None,
        treasury_donation: None,
      },
      redeemer: EndMultiSig { input_index: 0 },
      // Added the missing 'redeemer' field
      info: Minting(own_policy),
    }

  validate_multisig_end(own_policy, 0, context.transaction)
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
  let multisig_token_name = value.unique_token_name(tx_hash, 1, #"", "")

  let multisig_value =
    add(from_lovelace(contract_value), own_policy, multisig_token_name, 1)
  let multisig_input =
    tests.test_context_input_01(
      init_output_ref,
      own_policy,
      multisig_value,
      datum,
    )

  let output_datum =
    tests.test_multisig_datum(signatories, threshold, transaction_limit_value)
  let multisig_out_value = add(zero, own_policy, multisig_token_name, 1)
  let own_output =
    tests.test_utxo_02(
      own_policy,
      multisig_out_value,
      output_value,
      output_datum,
    )
  let recipient_output =
    tests.test_user_utxo(
      tests.test_withdraw_pkh(),
      from_lovelace(withdrawal_value),
      NoDatum,
    )
  let as_data: Data = datum

  // Create the transaction context
  let context =
    ScriptContext {
      transaction: Transaction {
        inputs: [multisig_input],
        reference_inputs: [],
        outputs: [own_output, recipient_output],
        fee: 0,
        mint: zero,
        certificates: [],
        withdrawals: [],
        validity_range: interval.everything,
        extra_signatories: signatories,
        redeemers: [],
        datums: dict.empty,
        id: tx_hash,
        votes: [],
        proposal_procedures: [],
        current_treasury_amount: None,
        treasury_donation: None,
      },
      redeemer: Sign { input_index: 0, output_index: 0 },
      // Added the missing 'redeemer' field
      info: Spending(init_output_ref, Some(as_data)),
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
  validate_sign(Some(datum), Pair(0, 0), init_output_ref, context.transaction)
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
  let multisig_token_name = value.unique_token_name(tx_hash, 1, #"", "")

  let multisig_value =
    add(from_lovelace(contract_value), own_policy, multisig_token_name, 1)
  let multisig_input =
    tests.test_context_input_01(
      init_output_ref,
      own_policy,
      multisig_value,
      datum,
    )

  let output_datum =
    tests.test_multisig_datum(signatories, threshold, transaction_limit_value)
  let multisig_out_value = add(zero, own_policy, multisig_token_name, 1)
  let own_output =
    tests.test_utxo_02(
      own_policy,
      multisig_out_value,
      output_value,
      output_datum,
    )
  let recipient_output =
    tests.test_user_utxo(
      tests.test_withdraw_pkh(),
      from_lovelace(withdrawal_value),
      NoDatum,
    )
  let as_data: Data = datum

  // Create the transaction context
  let context =
    ScriptContext {
      transaction: Transaction {
        inputs: [multisig_input],
        reference_inputs: [],
        outputs: [own_output, recipient_output],
        fee: 0,
        mint: zero,
        certificates: [],
        withdrawals: [],
        validity_range: interval.everything,
        extra_signatories: [pubkey_hash_01, pubkey_hash_02],
        redeemers: [],
        datums: dict.empty,
        id: tx_hash,
        votes: [],
        proposal_procedures: [],
        current_treasury_amount: None,
        treasury_donation: None,
      },
      redeemer: Sign { input_index: 0, output_index: 0 },
      // Added the missing 'redeemer' field
      info: Spending(init_output_ref, Some(as_data)),
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
  !validate_sign(Some(datum), Pair(0, 0), init_output_ref, context.transaction)
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

  let multisig_token_name = value.unique_token_name(tx_hash, 1, #"", "")

  let multisig_value =
    add(from_lovelace(contract_value), own_policy, multisig_token_name, 1)
  let multisig_input =
    tests.test_context_input_01(
      init_output_ref,
      own_policy,
      multisig_value,
      old_datum,
    )

  let multisig_out_value = add(zero, own_policy, multisig_token_name, 1)
  let own_output =
    tests.test_utxo_02(
      own_policy,
      multisig_out_value,
      contract_value,
      new_datum,
    )

  let as_data: Data = old_datum
  // Create the transaction context
  let context =
    ScriptContext {
      transaction: Transaction {
        inputs: [multisig_input],
        reference_inputs: [],
        outputs: [own_output],
        fee: 0,
        mint: zero,
        certificates: [],
        withdrawals: [],
        validity_range: interval.everything,
        extra_signatories: signatories,
        redeemers: [],
        datums: dict.empty,
        id: tx_hash,
        votes: [],
        proposal_procedures: [],
        current_treasury_amount: None,
        treasury_donation: None,
      },
      redeemer: Update { input_index: 0, output_index: 0 },
      // Added the missing 'redeemer' field
      info: Spending(init_output_ref, Some(as_data)),
    }

  trace @"Test: Successfully Adjusting Signature Threshold"
  trace @"Original signature threshold"
  trace cbor.diagnostic(old_threshold)
  trace @"Total number of signatories in the multisig"
  trace cbor.diagnostic(list.length(signatories))
  trace @"Current contract value (in lovelace)"
  trace cbor.diagnostic(from_lovelace(contract_value))
  trace @"New threshold value"
  trace cbor.diagnostic(new_threshold)
  trace @"Number of signatories approving this change"
  trace cbor.diagnostic(list.length(signatories))
  trace @"Contract value after threshold adjustment (should be unchanged)"
  trace cbor.diagnostic(from_lovelace(contract_value))
  trace @"Result: Signature threshold successfully updated!"
  // Call the validator function
  validate_update(
    Some(old_datum),
    Pair(0, 0),
    init_output_ref,
    context.transaction,
  )
}

test success_add_signer() {
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
  let new_pubkey_hash = tests.test_224_06()

  let old_signatories =
    [pubkey_hash_01, pubkey_hash_02, pubkey_hash_03, pubkey_hash_04]
  let new_signatories =
    [
      pubkey_hash_01, pubkey_hash_02, pubkey_hash_03, pubkey_hash_04,
      new_pubkey_hash,
    ]

  let threshold = 3
  let spending_limit = 1_000_000_000

  let old_datum =
    tests.test_multisig_datum(old_signatories, threshold, spending_limit)
  let new_datum =
    tests.test_multisig_datum(new_signatories, threshold, spending_limit)
  let multisig_token_name = value.unique_token_name(tx_hash, 1, #"", "")

  let multisig_value =
    add(from_lovelace(contract_value), own_policy, multisig_token_name, 1)
  let multisig_input =
    tests.test_context_input_01(
      init_output_ref,
      own_policy,
      multisig_value,
      old_datum,
    )

  let multisig_out_value = add(zero, own_policy, multisig_token_name, 1)

  let own_output =
    tests.test_utxo_02(
      own_policy,
      multisig_out_value,
      contract_value,
      new_datum,
    )

  let as_data: Data = old_datum
  // Create the transaction context
  let context =
    ScriptContext {
      transaction: Transaction {
        inputs: [multisig_input],
        reference_inputs: [],
        outputs: [own_output],
        fee: 0,
        mint: zero,
        certificates: [],
        withdrawals: [],
        validity_range: interval.everything,
        extra_signatories: old_signatories,
        redeemers: [],
        datums: dict.empty,
        id: tx_hash,
        votes: [],
        proposal_procedures: [],
        current_treasury_amount: None,
        treasury_donation: None,
      },
      redeemer: Update { input_index: 0, output_index: 0 },
      // Added the missing 'redeemer' field
      info: Spending(init_output_ref, Some(as_data)),
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

  validate_update(
    Some(old_datum),
    Pair(0, 0),
    init_output_ref,
    context.transaction,
  )
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
  let new_signatories = [pubkey_hash_01, pubkey_hash_02, pubkey_hash_03]

  let old_threshold = 3
  let new_threshold = 2
  // Adjust threshold to maintain validity
  let spending_limit = 1_000_000_000

  let old_datum =
    tests.test_multisig_datum(old_signatories, old_threshold, spending_limit)
  let new_datum =
    tests.test_multisig_datum(new_signatories, new_threshold, spending_limit)
  let multisig_token_name = value.unique_token_name(tx_hash, 1, #"", "")

  let multisig_value =
    add(from_lovelace(contract_value), own_policy, multisig_token_name, 1)
  let multisig_input =
    tests.test_context_input_01(
      init_output_ref,
      own_policy,
      multisig_value,
      old_datum,
    )

  let multisig_out_value = add(zero, own_policy, multisig_token_name, 1)
  let own_output =
    tests.test_utxo_02(
      own_policy,
      multisig_out_value,
      contract_value,
      new_datum,
    )

  let as_data: Data = old_datum

  // Create the transaction context
  let context =
    ScriptContext {
      transaction: Transaction {
        inputs: [multisig_input],
        reference_inputs: [],
        outputs: [own_output],
        fee: 0,
        mint: zero,
        certificates: [],
        withdrawals: [],
        validity_range: interval.everything,
        extra_signatories: old_signatories,
        redeemers: [],
        datums: dict.empty,
        id: tx_hash,
        votes: [],
        proposal_procedures: [],
        current_treasury_amount: None,
        treasury_donation: None,
      },
      redeemer: Update { input_index: 0, output_index: 0 },
      // Added the missing 'redeemer' field
      info: Spending(init_output_ref, Some(as_data)),
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

  validate_update(
    Some(old_datum),
    Pair(0, 0),
    init_output_ref,
    context.transaction,
  )
}

test succeed_remove_miltisig() {
  let own_policy = tests.test_policy()
  let tx_hash = tests.test_224_01()
  let init_output_ref = tests.test_input_utxo_02(tx_hash)

  // Create input and output UTxOs
  let transaction_limit_value = 1_000_000_000

  // 100,000 ADA
  let contract_value = 100_000_000_000
  let pubkey_hash_01 = tests.test_224_02()
  let pubkey_hash_02 = tests.test_224_03()
  let pubkey_hash_03 = tests.test_224_04()
  let pubkey_hash_04 = tests.test_224_05()

  let signatories =
    [pubkey_hash_01, pubkey_hash_02, pubkey_hash_03, pubkey_hash_04]

  let threshold = list.length(signatories) / 2 + 1

  let datum =
    tests.test_multisig_datum(signatories, threshold, transaction_limit_value)
  let multisig_token_name = value.unique_token_name(tx_hash, 1, #"", "")

  let multisig_value =
    add(from_lovelace(contract_value), own_policy, multisig_token_name, 1)
  let multisig_input =
    tests.test_context_input_01(
      init_output_ref,
      own_policy,
      multisig_value,
      datum,
    )

  let multisig_out_value = add(zero, own_policy, multisig_token_name, -1)

  let own_output =
    tests.test_utxo_02(
      own_policy,
      from_lovelace(2_000_000),
      contract_value,
      NoDatum,
    )
  let as_data: Data = datum

  let context =
    ScriptContext {
      transaction: Transaction {
        inputs: [multisig_input],
        // Should have two inputs.
        reference_inputs: [],
        outputs: [own_output],
        fee: 0,
        mint: multisig_out_value,
        certificates: [],
        withdrawals: [],
        validity_range: interval.everything,
        extra_signatories: [],
        redeemers: [],
        datums: dict.empty,
        id: tx_hash,
        votes: [],
        proposal_procedures: [],
        current_treasury_amount: None,
        treasury_donation: None,
      },
      redeemer: Remove { input_index: 0, output_index: 0 },
      // Added the missing 'redeemer' field
      info: Spending(init_output_ref, Some(as_data)),
    }

  validate_remove(Some(datum), Pair(0, 0), init_output_ref, context.transaction)
}
