use aiken/collection/dict
use aiken/collection/list
use aiken/interval.{everything}
use cardano/assets.{ada_asset_name, ada_policy_id, add, from_lovelace, zero}
use cardano/transaction.{InlineDatum, NoDatum, Output, Transaction}
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

  let tx_hash = tests.test_224_01()

  let pubkey_hash_01 = tests.test_224_02()
  let pubkey_hash_02 = tests.test_224_03()
  let pubkey_hash_03 = tests.test_224_04()
  let pubkey_hash_04 = tests.test_224_05()

  let signatories =
    [pubkey_hash_01, pubkey_hash_02, pubkey_hash_03, pubkey_hash_04]

  let threshold = list.length(signatories) / 2 + 1

  let own_ref = tests.test_input_utxo_02(tx_hash)
  let user_input =
    tests.test_context_input_01(
      own_ref,
      own_policy,
      assets.from_lovelace(contract_value),
      NoDatum,
    )

  let multisig_out_value =
    add(zero, own_policy, multisig_token_name(own_ref), 1)

  let output_datum =
    tests.test_multisig_datum(signatories, threshold, transaction_limit_value)

  let multisig_output =
    tests.test_utxo_02(
      own_policy,
      multisig_out_value,
      contract_value,
      output_datum,
    )

  let transaction =
    Transaction {
      inputs: [user_input],
      reference_inputs: [],
      outputs: [multisig_output],
      fee: 0,
      mint: multisig_out_value,
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

  (own_policy, own_ref, 0, output_datum, multisig_output, transaction)
}

test succeed_init_multisig() {
  let (own_policy, own_ref, idx, _output_datum, multisig_output, transaction) =
    base_init()

  let tx = Transaction { ..transaction, outputs: [multisig_output] }

  validate_initiate_multisig(own_policy, own_ref, idx, tx)
}

test fail_init_script_address() fail {
  let (_own_policy, own_ref, idx, _output_datum, multisig_output, transaction) =
    base_init()

  let wrong_policy = tests.test_wrong_policy()
  let tx = Transaction { ..transaction, outputs: [multisig_output] }

  validate_initiate_multisig(wrong_policy, own_ref, idx, tx)
}

test fail_init_no_signatories() fail {
  let (own_policy, own_ref, idx, _output_datum, multisig_output, transaction) =
    base_init()

  let transaction_limit_value = 1_000_000_000

  let signatories = []

  let threshold = 1

  let output_datum =
    tests.test_multisig_datum(signatories, threshold, transaction_limit_value)

  let wrong_multisig_output =
    Output { ..multisig_output, datum: InlineDatum(output_datum) }

  let tx = Transaction { ..transaction, outputs: [wrong_multisig_output] }

  validate_initiate_multisig(own_policy, own_ref, idx, tx)
}

test fail_init_threshold_too_large() fail {
  let (own_policy, own_ref, idx, _output_datum, multisig_output, transaction) =
    base_init()

  let transaction_limit_value = 1_000_000_000

  let pubkey_hash_01 = tests.test_224_02()
  let pubkey_hash_02 = tests.test_224_03()
  let pubkey_hash_03 = tests.test_224_04()
  let pubkey_hash_04 = tests.test_224_05()
  let signatories =
    [pubkey_hash_01, pubkey_hash_02, pubkey_hash_03, pubkey_hash_04]

  let threshold = list.length(signatories) + 1

  let output_datum =
    tests.test_multisig_datum(signatories, threshold, transaction_limit_value)

  let wrong_multisig_output =
    Output { ..multisig_output, datum: InlineDatum(output_datum) }

  let tx = Transaction { ..transaction, outputs: [wrong_multisig_output] }

  validate_initiate_multisig(own_policy, own_ref, idx, tx)
}

test fail_init_threshold_too_small() fail {
  let (own_policy, own_ref, idx, _output_datum, multisig_output, transaction) =
    base_init()

  let transaction_limit_value = 1_000_000_000

  let pubkey_hash_01 = tests.test_224_02()
  let pubkey_hash_02 = tests.test_224_03()
  let pubkey_hash_03 = tests.test_224_04()
  let pubkey_hash_04 = tests.test_224_05()
  let signatories =
    [pubkey_hash_01, pubkey_hash_02, pubkey_hash_03, pubkey_hash_04]

  let threshold = 0

  let output_datum =
    tests.test_multisig_datum(signatories, threshold, transaction_limit_value)

  let wrong_multisig_output =
    Output { ..multisig_output, datum: InlineDatum(output_datum) }

  let tx = Transaction { ..transaction, outputs: [wrong_multisig_output] }

  validate_initiate_multisig(own_policy, own_ref, idx, tx)
}

test fail_init_too_many_tokens() fail {
  let contract_value = 100_000_000_000
  let (
    own_policy,
    own_ref,
    idx,
    __oldoutput_datum,
    multisig_output,
    transaction,
  ) = base_init()

  let multisig_out_value =
    add(zero, own_policy, multisig_token_name(own_ref), 2)

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

  let tx = Transaction { ..transaction, outputs: [wrong_multisig_output] }

  validate_initiate_multisig(own_policy, own_ref, idx, tx)
}

test fail_init_too_little_tokens() fail {
  let contract_value = 100_000_000_000
  let (
    own_policy,
    own_ref,
    idx,
    __oldoutput_datum,
    multisig_output,
    transaction,
  ) = base_init()

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

  let tx = Transaction { ..transaction, outputs: [wrong_multisig_output] }

  validate_initiate_multisig(own_policy, own_ref, idx, tx)
}

test fail_init_wrong_token() fail {
  let contract_value = 100_000_000_000
  let (
    own_policy,
    own_ref,
    idx,
    __oldoutput_datum,
    multisig_output,
    transaction,
  ) = base_init()

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

  let tx = Transaction { ..transaction, outputs: [wrong_multisig_output] }

  validate_initiate_multisig(own_policy, own_ref, idx, tx)
}

fn base_end() {
  let (own_policy, own_ref, _idx, _output_datum, _multisig_output, _transaction) =
    base_init()

  // Create input and output UTxOs
  let transaction_limit_value = 1_000_000_000

  let contract_value = 100_000_000_000

  let tx_hash = tests.test_224_01()

  let pubkey_hash_01 = tests.test_224_02()
  let pubkey_hash_02 = tests.test_224_03()
  let pubkey_hash_03 = tests.test_224_04()
  let pubkey_hash_04 = tests.test_224_05()

  let signatories =
    [pubkey_hash_01, pubkey_hash_02, pubkey_hash_03, pubkey_hash_04]

  let threshold = list.length(signatories) / 2 + 1

  let multisig_token_name = multisig_token_name(own_ref)
  let multisig_value = add(zero, own_policy, multisig_token_name, 1)

  let user_input =
    tests.test_context_input_01(own_ref, own_policy, multisig_value, NoDatum)

  let multisig_out_value = add(zero, own_policy, multisig_token_name, -1)

  let output_datum =
    tests.test_multisig_datum(signatories, threshold, transaction_limit_value)

  let multisig_output =
    tests.test_utxo_02(
      own_policy,
      multisig_out_value,
      contract_value,
      output_datum,
    )

  let transaction =
    Transaction {
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
    }

  (
    own_policy,
    0,
    contract_value,
    output_datum,
    multisig_token_name,
    multisig_output,
    transaction,
  )
}

test succeed_end_multisig() {
  let (
    own_policy,
    idx,
    _contract_value,
    _output_datum,
    _multisig_token_name,
    multisig_output,
    transaction,
  ) = base_end()

  // let tx_hash = tests.test_224_01()
  // let own_policy = tests.test_policy()
  // let own_ref = tests.test_input_utxo_02(tx_hash)
  // let pubkey_hash_01 = tests.test_224_02()
  // let pubkey_hash_02 = tests.test_224_03()
  // let pubkey_hash_03 = tests.test_224_04()
  // let pubkey_hash_04 = tests.test_224_05()
  // let signatories =
  //   [pubkey_hash_01, pubkey_hash_02, pubkey_hash_03, pubkey_hash_04]
  // let threshold = list.length(signatories) / 2 + 1
  // let multisig_out_value = add(zero, own_policy, multisig_token_name, -1)
  // let output_datum =
  //   tests.test_multisig_datum(signatories, threshold, transaction_limit_value)
  // let multisig_output =
  //   tests.test_utxo_02(
  //     own_policy,
  //     multisig_out_value,
  //     contract_value,
  //     output_datum,
  //   )
  let tx = Transaction { ..transaction, outputs: [multisig_output] }

  validate_multisig_end(own_policy, idx, tx)
}

test fail_end_multisig_wrong_amount() fail {
  let (
    own_policy,
    idx,
    contract_value,
    output_datum,
    multisig_token_name,
    _multisig_output,
    transaction,
  ) = base_end()

  let multisig_out_value = add(zero, own_policy, multisig_token_name, -2)

  let multisig_output =
    tests.test_utxo_02(
      own_policy,
      multisig_out_value,
      contract_value,
      output_datum,
    )

  let tx =
    Transaction {
      ..transaction,
      mint: multisig_out_value,
      outputs: [multisig_output],
    }

  validate_multisig_end(own_policy, idx, tx)
}

fn base_sign() {
  let (own_policy, own_ref, _idx, _output_datum, _multisig_output, _transaction) =
    base_init()

  // Set up test data
  // let own_policy = tests.test_policy()
  let tx_hash = tests.test_224_01()
  // let init_output_ref = tests.test_input_utxo_02(tx_hash)
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

  let multisig_token_name = multisig_token_name(own_ref)

  let multisig_value =
    add(from_lovelace(contract_value), own_policy, multisig_token_name, 1)
  let multisig_input =
    tests.test_context_input_01(own_ref, own_policy, multisig_value, datum)

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

  (datum, own_ref, in_idx, out_idx, multisig_token_name, transaction)
}

test success_sign() {
  let (
    datum,
    init_output_ref,
    in_idx,
    out_idx,
    _multisig_token_name,
    transaction,
  ) = base_sign()
  validate_sign(datum, init_output_ref, in_idx, out_idx, transaction)
}

test fail_sign_insufficient_signatures() fail {
  let (
    datum,
    init_output_ref,
    in_idx,
    out_idx,
    _multisig_token_name,
    transaction,
  ) = base_sign()

  let pubkey_hash_01 = tests.test_224_02()
  let pubkey_hash_02 = tests.test_224_03()
  let wrong_transaction =
    Transaction {
      ..transaction,
      extra_signatories: [pubkey_hash_01, pubkey_hash_02],
    }

  validate_sign(datum, init_output_ref, in_idx, out_idx, wrong_transaction)
}

test fail_sign_wrong_spend_limit() fail {
  let (
    datum,
    init_output_ref,
    in_idx,
    out_idx,
    multisig_token_name,
    transaction,
  ) = base_sign()

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

  validate_sign(datum, init_output_ref, in_idx, out_idx, wrong_transaction)
}

test success_update_threshold() {
  let (
    datum,
    init_output_ref,
    in_idx,
    out_idx,
    multisig_token_name,
    transaction,
  ) = base_sign()

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

  validate_update(
    datum,
    init_output_ref,
    in_idx,
    out_idx,
    transaction_new_output,
  )
}

// Add two outputs with one output with an extra signer.
// (Change order of outputs)
test success_update_add_signer() {
  let (
    datum,
    init_output_ref,
    in_idx,
    out_idx,
    multisig_token_name,
    transaction,
  ) = base_sign()

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

  validate_update(
    datum,
    init_output_ref,
    in_idx,
    out_idx,
    transaction_new_output,
  )
}

test fail_update_double_satisfaction() fail {
  let (
    datum,
    init_output_ref,
    in_idx,
    out_idx,
    multisig_token_name,
    transaction,
  ) = base_sign()

  let own_policy = tests.test_policy()

  let pubkey_hash_01 = tests.test_224_02()
  let pubkey_hash_02 = tests.test_224_03()
  let pubkey_hash_03 = tests.test_224_04()
  let pubkey_hash_04 = tests.test_224_05()
  let pubkey_hash_05 = tests.test_224_06()
  let pubkey_hash_06 = tests.test_224_07()
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

  let strange_signatories = signatories |> list.concat([pubkey_hash_06])
  let strange_spending_limit = 10_000_000_000

  let strange_datum =
    tests.test_multisig_datum(
      strange_signatories,
      new_threshold,
      strange_spending_limit,
    )

  let strange_output =
    tests.test_utxo_02(
      own_policy,
      multisig_out_value,
      contract_value,
      strange_datum,
    )

  let tx_with_two_outputs =
    Transaction { ..transaction, outputs: [own_output, strange_output] }

  validate_update(datum, init_output_ref, in_idx, out_idx, tx_with_two_outputs)
}

test success_update_remove_signer() {
  let (
    datum,
    init_output_ref,
    in_idx,
    out_idx,
    multisig_token_name,
    transaction,
  ) = base_sign()

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

  validate_update(
    datum,
    init_output_ref,
    in_idx,
    out_idx,
    transaction_new_output,
  )
}

test success_update_remove_all_signers() {
  let (
    datum,
    init_output_ref,
    in_idx,
    out_idx,
    multisig_token_name,
    transaction,
  ) = base_sign()

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

  validate_update(
    datum,
    init_output_ref,
    in_idx,
    out_idx,
    transaction_new_output,
  )
}

test succeed_remove_miltisig() {
  let own_policy = tests.test_policy()
  let tx_hash = tests.test_224_01()
  let own_ref = tests.test_input_utxo_02(tx_hash)
  let multisig_token_name = multisig_token_name(own_ref)

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
    tests.test_context_input_01(own_ref, own_policy, multisig_value, datum)

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

  validate_remove(datum, own_ref, 0, transaction)
}
