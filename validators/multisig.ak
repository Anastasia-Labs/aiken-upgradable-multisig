use aiken/cbor
use aiken/dict
use aiken/hash.{Blake2b_224, Hash}
use aiken/interval
use aiken/list
use aiken/transaction.{
  Input, NoDatum, Output, ScriptContext, Spend, Transaction, TransactionId,
}
use aiken/transaction/credential.{Script, VerificationKey}
use aiken/transaction/value.{Value}
use assist/data
use upgradable_multisig/tests
use upgradable_multisig/types.{
  AssetClass, MultisigDatum, MultisigRedeemer, Sign, Update,
}

// Sum up all the values from the outputs into a single Value.
// Compare this total output value with the input value to ensure no assets are lost.
fn value_preserved(input_value: Value, outputs: List<Output>) -> Bool {
  let total_output_value =
    outputs
      |> list.foldl(
          value.zero(),
          fn(output, acc) { value.merge(acc, output.value) },
        )
  value.flatten(input_value)
    |> list.all(
        fn(asset) {
          let (policy_id, asset_name, qty) = asset
          value.quantity_of(total_output_value, policy_id, asset_name) >= qty
        },
      )
}

fn amount_spent_correctly(
  input_value: Value,
  output_value: Value,
  funds: AssetClass,
  amount: Int,
) -> Bool {
  let AssetClass { policy_id, asset_name } = funds
  let input_qty = value.quantity_of(input_value, policy_id, asset_name)
  let output_qty = value.quantity_of(output_value, policy_id, asset_name)
  input_qty - output_qty == amount
}

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
    expect [own_output, recipient_output, ..] = outputs

    trace @"own_output"
    trace cbor.diagnostic(own_output)
    trace @"recipient_output"
    trace cbor.diagnostic(recipient_output)

    // let signed_by_majority =
    //   list.length(
    //     list.filter(extra_signatories, fn(sig) { list.has(datum.signers, sig) }),
    //   ) >= datum.threshold
    let matching_signers =
      list.filter(extra_signatories, fn(sig) { list.has(datum.signers, sig) })

    trace @"matching_signers"
    trace cbor.diagnostic(matching_signers)

    let signed_by_majority = list.length(matching_signers) >= datum.threshold

    trace @"signed_by_majority"
    trace cbor.diagnostic(signed_by_majority)
    trace @"datum.threshold"
    trace cbor.diagnostic(datum.threshold)

    // Common checks
    let common_checks =
      signed_by_majority && value_preserved(own_input.output.value, outputs)

    when redeemer is {
      Sign ->
        common_checks && validate_sign(
          datum,
          own_input,
          own_output,
          recipient_output,
        )
      Update -> common_checks && validate_update(own_input, own_output)
    }
  }
}

fn get_asset_amount(value: Value, asset: AssetClass) -> Int {
  value.quantity_of(value, asset.policy_id, asset.asset_name)
}

fn validate_sign(
  datum: MultisigDatum,
  own_input: Input,
  own_output: Output,
  recipient_output: Output,
) -> Bool {
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

  // Calculate the transfer amount
  if transfer_amount > datum.spending_limit {
    trace @"Transfer amount exceeds spending limit"
    False
  } else if recipient_amount != transfer_amount {
    trace @"Incorrect amount transferred to recipient"
    False
  } else {
    // Validate that the datum is updated correctly
    expect output_datum: MultisigDatum = data.output_datum(own_output)
    is_datum_valid(datum, output_datum, output_amount)
  }
}

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

fn validate_update(own_input: Input, own_output: Output) -> Bool {
  // Validate that the output datum is updated correctly
  expect output_datum: MultisigDatum = data.output_datum(own_output)
  let new_datum: MultisigDatum = output_datum
  // Ensure the new signers list is not empty
  let new_signer_count = list.length(new_datum.signers)
  if new_signer_count == 0 {
    trace @"New signers list is empty"
    False
  } else if new_datum.threshold <= 0 || new_datum.threshold > new_signer_count {
    trace @"Invalid new threshold"
    False
  } else if list.length(list.unique(new_datum.signers)) != new_signer_count {
    trace @"Duplicate signers in new list"
    False
  } else if new_datum.funds_qty < 0 {
    trace @"Invalid new funds quantity"
    False
  } else if new_datum.spending_limit <= 0 || new_datum.spending_limit > new_datum.funds_qty {
    trace @"Invalid new spending limit"
    False
  } else if new_datum.funds_qty != get_asset_amount(
    own_output.value,
    new_datum.funds,
  ) {
    trace @"Funds quantity in datum doesn't match actual value"
    False
  } else {
    // Ensure the total value remains unchanged during updates
    values_equal(own_output.value, own_input.output.value)
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
