use aiken/collection/dict
use aiken/collection/list
use aiken/interval.{everything}
use cardano/assets.{add, from_lovelace, zero}
use cardano/transaction.{Input, NoDatum, Transaction}
use upgradable_multisig/multisig/utils.{multisig_token_name}
use upgradable_multisig/multisig/validation.{
  validate_initiate_multisig, validate_multisig_end, validate_remove,
  validate_sign, validate_update,
}
use upgradable_multisig/tests/tests

test succeed_initiate_multisig() {
  let own_policy = tests.test_policy()

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

  validate_initiate_multisig(
    own_policy,
    0,
    multisig_out_value,
    [multisig_output],
  )
}

test succeed_end_multisig() {
  let own_policy = tests.test_policy()

  let multisig_out_value = add(zero, own_policy, multisig_token_name, -1)

  validate_multisig_end(own_policy, multisig_out_value)
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

  // Create the transaction context
  let transaction =
    Transaction {
      inputs: [multisig_input],
      reference_inputs: [],
      outputs: [own_output, recipient_output],
      fee: 0,
      mint: zero,
      certificates: [],
      withdrawals: [],
      validity_range: everything,
      extra_signatories: signatories,
      redeemers: [],
      datums: dict.empty,
      id: tx_hash,
      votes: [],
      proposal_procedures: [],
      current_treasury_amount: None,
      treasury_donation: None,
    }

  // Call the validator function
  validate_sign(datum, init_output_ref, 0, 0, transaction)
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

  // Create the transaction context
  let transaction =
    Transaction {
      inputs: [multisig_input],
      reference_inputs: [],
      outputs: [own_output, recipient_output],
      fee: 0,
      mint: zero,
      certificates: [],
      withdrawals: [],
      validity_range: everything,
      extra_signatories: [pubkey_hash_01, pubkey_hash_02],
      redeemers: [],
      datums: dict.empty,
      id: tx_hash,
      votes: [],
      proposal_procedures: [],
      current_treasury_amount: None,
      treasury_donation: None,
    }

  // Call the validator function
  !validate_sign(datum, multisig_input.output_reference, 0, 0, transaction)
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

  // Create the transaction context
  let transaction =
    Transaction {
      inputs: [multisig_input],
      reference_inputs: [],
      outputs: [own_output],
      fee: 0,
      mint: zero,
      certificates: [],
      withdrawals: [],
      validity_range: everything,
      extra_signatories: signatories,
      redeemers: [],
      datums: dict.empty,
      id: tx_hash,
      votes: [],
      proposal_procedures: [],
      current_treasury_amount: None,
      treasury_donation: None,
    }

  validate_update(old_datum, multisig_input.output_reference, 0, 0, transaction)
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

  // Create the transaction context
  let transaction =
    Transaction {
      inputs: [multisig_input],
      reference_inputs: [],
      outputs: [own_output],
      fee: 0,
      mint: zero,
      certificates: [],
      withdrawals: [],
      validity_range: everything,
      extra_signatories: old_signatories,
      redeemers: [],
      datums: dict.empty,
      id: tx_hash,
      votes: [],
      proposal_procedures: [],
      current_treasury_amount: None,
      treasury_donation: None,
    }

  validate_update(old_datum, multisig_input.output_reference, 0, 0, transaction)
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

  // Create the transaction context
  let transaction =
    Transaction {
      inputs: [multisig_input],
      reference_inputs: [],
      outputs: [own_output],
      fee: 0,
      mint: zero,
      certificates: [],
      withdrawals: [],
      validity_range: everything,
      extra_signatories: old_signatories,
      redeemers: [],
      datums: dict.empty,
      id: tx_hash,
      votes: [],
      proposal_procedures: [],
      current_treasury_amount: None,
      treasury_donation: None,
    }

  validate_update(old_datum, multisig_input.output_reference, 0, 0, transaction)
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

  let transaction =
    Transaction {
      inputs: [multisig_input],
      reference_inputs: [],
      outputs: [own_output],
      fee: 0,
      mint: multisig_out_value,
      certificates: [],
      withdrawals: [],
      validity_range: everything,
      extra_signatories: [pubkey_hash_02, pubkey_hash_01, pubkey_hash_04],
      redeemers: [],
      datums: dict.empty,
      id: tx_hash,
      votes: [],
      proposal_procedures: [],
      current_treasury_amount: None,
      treasury_donation: None,
    }

  validate_remove(datum, init_output_ref, 0, transaction)
}
