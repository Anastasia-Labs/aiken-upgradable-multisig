use aiken/collection/dict
use aiken/collection/list
use aiken/interval.{everything}
use cardano/assets.{ada_asset_name, ada_policy_id, add, from_lovelace, zero}
use cardano/transaction.{InlineDatum, Input, NoDatum, Output, Transaction}
use upgradable_multisig/multisig/utils.{multisig_token_name}
use upgradable_multisig/multisig/validation.{
  validate_initiate_multisig, validate_multisig_end, validate_remove,
  validate_sign, validate_update,
}
use upgradable_multisig/tests/tests

fn base_init() {
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

  (own_policy, 0, multisig_out_value, multisig_output)
}

test succeed_init_multisig() {
  let (own_policy, idx, multisig_out_value, multisig_output) = base_init()

  validate_initiate_multisig(
    own_policy,
    idx,
    multisig_out_value,
    [multisig_output],
  )
}

test fail_init_script_address() fail {
  let (_own_policy, idx, multisig_out_value, multisig_output) = base_init()

  let wrong_policy = tests.test_wrong_policy()

  validate_initiate_multisig(
    wrong_policy,
    idx,
    multisig_out_value,
    [multisig_output],
  )
}

test fail_init_no_signatories() fail {
  let (own_policy, idx, multisig_out_value, multisig_output) = base_init()

  let transaction_limit_value = 1_000_000_000

  let signatories = []

  let threshold = 1

  let multisig_out_value = add(zero, own_policy, multisig_token_name, 1)

  let output_datum =
    tests.test_multisig_datum(signatories, threshold, transaction_limit_value)

  let wrong_multisig_output =
    Output { ..multisig_output, datum: InlineDatum(output_datum) }

  validate_initiate_multisig(
    own_policy,
    0,
    multisig_out_value,
    [wrong_multisig_output],
  )
}

test fail_init_threshold_too_large() fail {
  let (own_policy, idx, multisig_out_value, multisig_output) = base_init()

  let transaction_limit_value = 1_000_000_000

  let pubkey_hash_01 = tests.test_224_02()
  let pubkey_hash_02 = tests.test_224_03()
  let pubkey_hash_03 = tests.test_224_04()
  let pubkey_hash_04 = tests.test_224_05()
  let signatories =
    [pubkey_hash_01, pubkey_hash_02, pubkey_hash_03, pubkey_hash_04]

  let threshold = list.length(signatories) + 1

  let multisig_out_value = add(zero, own_policy, multisig_token_name, 1)

  let output_datum =
    tests.test_multisig_datum(signatories, threshold, transaction_limit_value)

  let wrong_multisig_output =
    Output { ..multisig_output, datum: InlineDatum(output_datum) }

  validate_initiate_multisig(
    own_policy,
    0,
    multisig_out_value,
    [wrong_multisig_output],
  )
}

test fail_init_threshold_too_small() fail {
  let (own_policy, idx, multisig_out_value, multisig_output) = base_init()

  let transaction_limit_value = 1_000_000_000

  let pubkey_hash_01 = tests.test_224_02()
  let pubkey_hash_02 = tests.test_224_03()
  let pubkey_hash_03 = tests.test_224_04()
  let pubkey_hash_04 = tests.test_224_05()
  let signatories =
    [pubkey_hash_01, pubkey_hash_02, pubkey_hash_03, pubkey_hash_04]

  let threshold = 0

  let multisig_out_value = add(zero, own_policy, multisig_token_name, 1)

  let output_datum =
    tests.test_multisig_datum(signatories, threshold, transaction_limit_value)

  let wrong_multisig_output =
    Output { ..multisig_output, datum: InlineDatum(output_datum) }

  validate_initiate_multisig(
    own_policy,
    0,
    multisig_out_value,
    [wrong_multisig_output],
  )
}

test fail_init_too_many_tokens() fail {
  let contract_value = 100_000_000_000
  let (own_policy, idx, multisig_out_value, multisig_output) = base_init()

  let multisig_out_value = add(zero, own_policy, multisig_token_name, 2)

  let wrong_multisig_output =
    Output {
      ..multisig_output,
      value: add(
        multisig_out_value,
        ada_policy_id,
        ada_asset_name,
        contract_value,
      ),
    }

  validate_initiate_multisig(
    own_policy,
    0,
    multisig_out_value,
    [multisig_output],
  )
}

test fail_init_too_little_tokens() fail {
  let contract_value = 100_000_000_000
  let (own_policy, idx, multisig_out_value, multisig_output) = base_init()

  let multisig_out_value = from_lovelace(contract_value)

  let wrong_multisig_output =
    Output {
      ..multisig_output,
      value: add(
        multisig_out_value,
        ada_policy_id,
        ada_asset_name,
        contract_value,
      ),
    }

  validate_initiate_multisig(
    own_policy,
    0,
    multisig_out_value,
    [multisig_output],
  )
}

test fail_init_wrong_token() fail {
  let contract_value = 100_000_000_000
  let (own_policy, idx, multisig_out_value, multisig_output) = base_init()

  let multisig_out_value = add(zero, own_policy, "not_multisig_token_name", 1)

  let wrong_multisig_output =
    Output {
      ..multisig_output,
      value: add(
        multisig_out_value,
        ada_policy_id,
        ada_asset_name,
        contract_value,
      ),
    }

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

test fail_end_multisig_wrong_token() fail {
  let own_policy = tests.test_policy()

  let multisig_out_value = add(zero, own_policy, "not_multisig_token_name", -1)

  validate_multisig_end(own_policy, multisig_out_value)
}

test fail_end_multisig_wrong_amount() fail {
  let own_policy = tests.test_policy()

  let multisig_out_value = add(zero, own_policy, multisig_token_name, -2)

  validate_multisig_end(own_policy, multisig_out_value)
}

fn base_sign() {
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

  let in_idx = 0
  let out_idx = 0

  (datum, init_output_ref, in_idx, out_idx, transaction)
}

test success_sign() {
  let (datum, init_output_ref, in_idx, out_idx, transaction) = base_sign()
  validate_sign(datum, init_output_ref, in_idx, out_idx, transaction)
}

test fail_sign_insufficient_signatures() fail {
  let (datum, init_output_ref, in_idx, out_idx, transaction) = base_sign()

  let pubkey_hash_01 = tests.test_224_02()
  let pubkey_hash_02 = tests.test_224_03()
  let wrong_transaction =
    Transaction {
      ..transaction,
      extra_signatories: [pubkey_hash_01, pubkey_hash_02],
    }

  validate_sign(datum, init_output_ref, 0, 0, wrong_transaction)
}

test fail_sign_wrong_spend_limit() fail {
  let (datum, init_output_ref, in_idx, out_idx, transaction) = base_sign()

  let own_policy = tests.test_policy()
  let multisig_out_value = add(zero, own_policy, multisig_token_name, 1)
  let own_output =
    tests.test_utxo_02(own_policy, multisig_out_value, 1_000_000_000_000, datum)

  let recipient_output =
    tests.test_user_utxo(
      tests.test_withdraw_pkh(),
      from_lovelace(1_000_000_000_000),
      NoDatum,
    )

  let wrong_transaction =
    // Why it's not failing?
    Transaction { ..transaction, outputs: [own_output, recipient_output] }

  validate_sign(datum, init_output_ref, 0, 0, wrong_transaction)
}

test success_update_threshold() {
  let (datum, init_output_ref, in_idx, out_idx, transaction) = base_sign()

  let own_policy = tests.test_policy()

  let pubkey_hash_01 = tests.test_224_02()
  let pubkey_hash_02 = tests.test_224_03()
  let pubkey_hash_03 = tests.test_224_04()
  let pubkey_hash_04 = tests.test_224_05()
  let signatories =
    [pubkey_hash_01, pubkey_hash_02, pubkey_hash_03, pubkey_hash_04]

  let new_threshold = 0
  // Surprising that it's possible
  let spending_limit = 1_000_000_000
  let contract_value = 100_000_000_000

  let new_datum =
    tests.test_multisig_datum(signatories, new_threshold, spending_limit)
  let multisig_out_value = add(zero, own_policy, multisig_token_name, 1)
  let own_output =
    tests.test_utxo_02(
      own_policy,
      multisig_out_value,
      contract_value,
      new_datum,
    )

  let transaction_new_output =
    Transaction { ..transaction, outputs: [own_output] }

  validate_update(datum, init_output_ref, 0, 0, transaction_new_output)
}

test success_update_add_signer() {
  let (datum, init_output_ref, in_idx, out_idx, transaction) = base_sign()

  let own_policy = tests.test_policy()

  let pubkey_hash_01 = tests.test_224_02()
  let pubkey_hash_02 = tests.test_224_03()
  let pubkey_hash_03 = tests.test_224_04()
  let pubkey_hash_04 = tests.test_224_05()
  let pubkey_hash_05 = tests.test_224_06()
  let signatories =
    [
      pubkey_hash_01, pubkey_hash_02, pubkey_hash_03, pubkey_hash_04,
      pubkey_hash_05,
    ]

  let new_threshold = 3
  let spending_limit = 1_000_000_000
  let contract_value = 100_000_000_000

  let new_datum =
    tests.test_multisig_datum(signatories, new_threshold, spending_limit)
  let multisig_out_value = add(zero, own_policy, multisig_token_name, 1)
  let own_output =
    tests.test_utxo_02(
      own_policy,
      multisig_out_value,
      contract_value,
      new_datum,
    )

  let transaction_new_output =
    Transaction { ..transaction, outputs: [own_output] }

  validate_update(datum, init_output_ref, 0, 0, transaction_new_output)
}

test success_update_remove_signer() {
  let (datum, init_output_ref, in_idx, out_idx, transaction) = base_sign()

  let own_policy = tests.test_policy()

  let pubkey_hash_01 = tests.test_224_02()
  let signatories = [pubkey_hash_01]

  let new_threshold = 3
  // Lost the funds
  let spending_limit = 1_000_000_000
  let contract_value = 100_000_000_000

  let new_datum =
    tests.test_multisig_datum(signatories, new_threshold, spending_limit)
  let multisig_out_value = add(zero, own_policy, multisig_token_name, 1)
  let own_output =
    tests.test_utxo_02(
      own_policy,
      multisig_out_value,
      contract_value,
      new_datum,
    )

  let transaction_new_output =
    Transaction { ..transaction, outputs: [own_output] }

  validate_update(datum, init_output_ref, 0, 0, transaction_new_output)
}

test success_update_remove_signers() {
  let (datum, init_output_ref, in_idx, out_idx, transaction) = base_sign()

  let own_policy = tests.test_policy()

  let signatories = []

  // That's possible as well?
  let new_threshold = 0
  let spending_limit = 1_000_000_000
  let contract_value = 100_000_000_000

  let new_datum =
    tests.test_multisig_datum(signatories, new_threshold, spending_limit)
  let multisig_out_value = add(zero, own_policy, multisig_token_name, 1)
  let own_output =
    tests.test_utxo_02(
      own_policy,
      multisig_out_value,
      contract_value,
      new_datum,
    )

  let transaction_new_output =
    Transaction { ..transaction, outputs: [own_output] }

  validate_update(datum, init_output_ref, 0, 0, transaction_new_output)
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
