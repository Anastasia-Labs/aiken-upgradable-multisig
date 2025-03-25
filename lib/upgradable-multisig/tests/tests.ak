use aiken/collection/dict
use aiken/collection/list
use aiken/crypto.{Signature, blake2b_256}
use aiken/fuzz.{and_then}
use aiken/interval.{everything}
use aiken/primitive/bytearray
use cardano/address.{Address, Inline, Script, VerificationKey}
use cardano/assets.{
  PolicyId, Value, ada_asset_name, ada_policy_id, add, merge, zero,
}
use cardano/transaction.{
  InlineDatum, Input, NoDatum, Output, OutputReference, Transaction,
}
use upgradable_multisig/multisig/utils.{multisig_token_name}
use upgradable_multisig/types.{MultisigDatum}

pub fn lovelace_value_fuzzer(
  min_lovelaces: Int,
  max_lovelaces: Int,
) -> Fuzzer<(Value, Int)> {
  let lovelace_count <- and_then(fuzz.int_between(min_lovelaces, max_lovelaces))
  let lovelace_value = assets.from_lovelace(lovelace_count)
  fuzz.constant((lovelace_value, lovelace_count))
}

fn number_of_signatores_fuzzer() -> Fuzzer<Int> {
  fuzz.int_between(1, 10)
}

fn signatures_fuzzer(number_of_signatores: Int) -> Fuzzer<List<Signature>> {
  // Couldn't find a better way to generate exactly n random signatures
  fuzz.list_between(
    fuzz.bytearray_fixed(28),
    number_of_signatores,
    number_of_signatores,
  )
}

fn threshold_fuzzer(number_of_signatores: Int) -> Fuzzer<Int> {
  fuzz.int_between(1, number_of_signatores)
}

pub fn datum_fuzzer(
  number_of_signatores: Int,
  spending_limit: Int,
) -> Fuzzer<MultisigDatum> {
  let init_signers <- and_then(signatures_fuzzer(number_of_signatores))
  let signers =
    // Not unique signers are allowed
    list.sort(init_signers, bytearray.compare)
  let signer_threshold <- and_then(threshold_fuzzer(list.length(signers)))

  fuzz.constant(
    MultisigDatum {
      signers,
      threshold: signer_threshold,
      fund_policy_id: ada_policy_id,
      fund_asset_name: ada_asset_name,
      spending_limit,
    },
  )
}

pub fn init_multisig_fuzzer(
  min_lovelaces: Int,
  max_lovelaces: Int,
) -> Fuzzer<(PolicyId, OutputReference, Int, Transaction)> {
  let own_policy <- and_then(fuzz.bytearray_fixed(28))
  let tx_hash <- and_then(fuzz.bytearray_fixed(28))
  let input_output_ref =
    OutputReference { transaction_id: tx_hash, output_index: 1 }

  let (locked_lovelace_value, locked_lovelace_count) <-
    and_then(lovelace_value_fuzzer(min_lovelaces, max_lovelaces))

  let input =
    Input {
      output_reference: input_output_ref,
      output: Output {
        address: Address(Script(own_policy), None),
        value: locked_lovelace_value,
        datum: NoDatum,
        reference_script: None,
      },
    }

  let stake_key_hash <- and_then(fuzz.bytearray_fixed(28))

  let spending_limit <- and_then(fuzz.int_between(0, locked_lovelace_count))

  let number_of_signatores <- and_then(number_of_signatores_fuzzer())
  let datum <- and_then(datum_fuzzer(number_of_signatores, spending_limit))
  let multisig_nft_value =
    add(zero, own_policy, multisig_token_name(input_output_ref), 1)
  let output =
    Output {
      address: Address {
        payment_credential: Script(own_policy),
        stake_credential: Some(Inline(VerificationKey(stake_key_hash))),
      },
      value: merge(locked_lovelace_value, multisig_nft_value),
      datum: InlineDatum(datum),
      reference_script: None,
    }

  let extra_signers <- and_then(fuzz.list_at_most(fuzz.bytearray_fixed(28), 3))
  let sorted_signers_with_extra =
    list.sort(list.concat(datum.signers, extra_signers), bytearray.compare)

  let transaction =
    Transaction {
      inputs: [input],
      reference_inputs: [],
      outputs: [output],
      fee: 0,
      mint: multisig_nft_value,
      certificates: [],
      withdrawals: [],
      validity_range: everything,
      extra_signatories: sorted_signers_with_extra |> list.unique,
      redeemers: [],
      datums: dict.empty,
      id: tx_hash,
      votes: [],
      proposal_procedures: [],
      current_treasury_amount: None,
      treasury_donation: None,
    }

  let out_idx = 0

  fuzz.constant((own_policy, input_output_ref, out_idx, transaction))
}

pub fn datum_fail_fuzzer(
  number_of_signatores: Int,
  spending_limit: Int,
  fail_points: List<String>,
) -> Fuzzer<MultisigDatum> {
  let signers <- and_then(signatures_fuzzer(number_of_signatores))
  let signer_threshold <-
    and_then(
      if list.has(fail_points, @"datum_number_of_signatores") {
        fuzz.either(
          fuzz.int_between(-255, 0),
          fuzz.int_between(number_of_signatores, 255),
        )
      } else {
        fuzz.int_between(1, number_of_signatores)
      },
    )

  // We assume that there is no reason to check other data fields
  fuzz.constant(
    MultisigDatum {
      signers: list.sort(signers, bytearray.compare),
      threshold: signer_threshold,
      fund_policy_id: ada_policy_id,
      fund_asset_name: ada_asset_name,
      spending_limit,
    },
  )
}

pub fn mint_multisig_fail_fuzzer(
  own_policy: PolicyId,
  input_output_ref: OutputReference,
  fail_points: List<String>,
) -> Fuzzer<Value> {
  if list.has(fail_points, @"multisig_nft_amount_mint") {
    let amount <-
      and_then(fuzz.either(fuzz.int_between(-255, 0), fuzz.int_between(2, 255)))
    fuzz.constant(
      add(zero, own_policy, multisig_token_name(input_output_ref), amount),
    )
  } else {
    if list.has(fail_points, @"multisig_nft_token_name") {
      let tx_hash <- and_then(fuzz.bytearray_fixed(28))
      let new_input_output_ref =
        OutputReference { transaction_id: tx_hash, output_index: 1 }
      fuzz.constant(
        add(zero, own_policy, multisig_token_name(new_input_output_ref), 1),
      )
    } else {
      fuzz.constant(
        add(zero, own_policy, multisig_token_name(input_output_ref), 1),
      )
    }
  }
}

pub fn burn_multisig_fail_fuzzer(
  own_policy: PolicyId,
  input_output_ref: OutputReference,
  fail_points: List<String>,
) -> Fuzzer<Value> {
  if list.has(fail_points, @"multisig_nft_amount_burn") {
    let amount <-
      and_then(
        fuzz.either(fuzz.int_between(-255, -2), fuzz.int_between(0, 255)),
      )
    fuzz.constant(
      add(zero, own_policy, multisig_token_name(input_output_ref), amount),
    )
  } else {
    if list.has(fail_points, @"multisig_nft_token_name") {
      let tx_hash <- and_then(fuzz.bytearray_fixed(28))
      let new_input_output_ref =
        OutputReference { transaction_id: tx_hash, output_index: 1 }
      fuzz.constant(
        add(zero, own_policy, multisig_token_name(new_input_output_ref), -1),
      )
    } else {
      fuzz.constant(
        add(zero, own_policy, multisig_token_name(input_output_ref), -1),
      )
    }
  }
}

pub fn lose_signers_fuzzer(
  signers: List<Signature>,
  fail_points: List<String>,
) -> Fuzzer<List<Signature>> {
  let reduced_signers =
    if list.has(fail_points, @"lost_signers") {
      expect Some(part_of_signers) = list.tail(signers)
      part_of_signers
    } else {
      signers
    }

  let extra_signers <- and_then(fuzz.list_at_most(fuzz.bytearray_fixed(28), 3))

  fuzz.constant(
    list.sort(list.concat(reduced_signers, extra_signers), bytearray.compare),
  )
}

pub fn init_fail_points_fuzzer() -> Fuzzer<List<String>> {
  fuzz.set_between(
    fuzz.map(
      fuzz.pick(
        [
          @"datum_number_of_signatores", @"multisig_nft_amount_mint",
          @"multisig_nft_token_name", @"lost_signers",
        ],
      ),
      fn((_a, b)) { b },
    ),
    1,
    4,
  )
}

pub fn init_multisig_fail_fuzzer(
  min_lovelaces: Int,
  max_lovelaces: Int,
) -> Fuzzer<(PolicyId, OutputReference, Int, Transaction, List<String>)> {
  let fail_points <- and_then(init_fail_points_fuzzer())

  let own_policy <- and_then(fuzz.bytearray_fixed(28))
  let tx_hash <- and_then(fuzz.bytearray_fixed(28))
  let input_output_ref =
    OutputReference { transaction_id: tx_hash, output_index: 1 }

  let (locked_lovelace_value, locked_lovelace_count) <-
    and_then(lovelace_value_fuzzer(min_lovelaces, max_lovelaces))

  let input =
    Input {
      output_reference: input_output_ref,
      output: Output {
        address: Address(Script(own_policy), None),
        value: locked_lovelace_value,
        datum: NoDatum,
        reference_script: None,
      },
    }

  let stake_key_hash <- and_then(fuzz.bytearray_fixed(28))

  let spending_limit <- and_then(fuzz.int_between(0, locked_lovelace_count))
  let number_of_signatores <- and_then(number_of_signatores_fuzzer())
  let datum <-
    and_then(
      datum_fail_fuzzer(number_of_signatores, spending_limit, fail_points),
    )
  let multisig_nft_value <-
    and_then(
      mint_multisig_fail_fuzzer(own_policy, input_output_ref, fail_points),
    )

  let output =
    Output {
      address: Address {
        payment_credential: Script(own_policy),
        stake_credential: Some(Inline(VerificationKey(stake_key_hash))),
      },
      value: merge(locked_lovelace_value, multisig_nft_value),
      datum: InlineDatum(datum),
      reference_script: None,
    }

  let sorted_signers <-
    and_then(lose_signers_fuzzer(datum.signers, fail_points))

  let transaction =
    Transaction {
      inputs: [input],
      reference_inputs: [],
      outputs: [output],
      fee: 0,
      mint: multisig_nft_value,
      certificates: [],
      withdrawals: [],
      validity_range: everything,
      extra_signatories: sorted_signers |> list.unique(),
      redeemers: [],
      datums: dict.empty,
      id: tx_hash,
      votes: [],
      proposal_procedures: [],
      current_treasury_amount: None,
      treasury_donation: None,
    }

  let out_idx = 0

  fuzz.constant(
    (own_policy, input_output_ref, out_idx, transaction, fail_points),
  )
}

pub fn end_multisig_fuzzer(
  min_lovelaces: Int,
  max_lovelaces: Int,
) -> Fuzzer<(PolicyId, Int, Transaction)> {
  let own_policy <- and_then(fuzz.bytearray_fixed(28))
  let tx_hash <- and_then(fuzz.bytearray_fixed(28))
  let input_output_ref =
    OutputReference { transaction_id: tx_hash, output_index: 1 }
  let (locked_lovelace_value, locked_lovelace_count) <-
    and_then(lovelace_value_fuzzer(min_lovelaces, max_lovelaces))
  let multisig_nft_value =
    add(zero, own_policy, multisig_token_name(input_output_ref), 1)

  let input =
    Input {
      output_reference: input_output_ref,
      output: Output {
        address: Address(Script(own_policy), None),
        value: merge(locked_lovelace_value, multisig_nft_value),
        datum: NoDatum,
        reference_script: None,
      },
    }

  let stake_key_hash <- and_then(fuzz.bytearray_fixed(28))
  let spending_limit <- and_then(fuzz.int_between(0, locked_lovelace_count))

  let number_of_signatores <- and_then(number_of_signatores_fuzzer())
  let datum <- and_then(datum_fuzzer(number_of_signatores, spending_limit))
  let output =
    Output {
      address: Address {
        payment_credential: Script(own_policy),
        stake_credential: Some(Inline(VerificationKey(stake_key_hash))),
      },
      value: locked_lovelace_value,
      datum: InlineDatum(datum),
      reference_script: None,
    }

  let extra_signers <- and_then(fuzz.list_at_most(fuzz.bytearray_fixed(28), 3))
  let sorted_signers_with_extra =
    list.sort(list.concat(datum.signers, extra_signers), bytearray.compare)

  let transaction =
    Transaction {
      inputs: [input],
      reference_inputs: [],
      outputs: [output],
      fee: 0,
      mint: add(zero, own_policy, multisig_token_name(input_output_ref), -1),
      certificates: [],
      withdrawals: [],
      validity_range: everything,
      extra_signatories: sorted_signers_with_extra,
      redeemers: [],
      datums: dict.empty,
      id: tx_hash,
      votes: [],
      proposal_procedures: [],
      current_treasury_amount: None,
      treasury_donation: None,
    }

  let out_idx = 0

  fuzz.constant((own_policy, out_idx, transaction))
}

pub fn end_fail_points_fuzzer() -> Fuzzer<List<String>> {
  fuzz.set_between(
    fuzz.map(
      fuzz.pick([@"multisig_nft_amount_burn", @"multisig_nft_token_name"]),
      fn((_a, b)) { b },
    ),
    1,
    2,
  )
}

pub fn end_multisig_fail_fuzzer(
  min_lovelaces: Int,
  max_lovelaces: Int,
) -> Fuzzer<(PolicyId, Int, Transaction, List<String>)> {
  let fail_points <- and_then(end_fail_points_fuzzer())
  let own_policy <- and_then(fuzz.bytearray_fixed(28))
  let tx_hash <- and_then(fuzz.bytearray_fixed(28))
  let input_output_ref =
    OutputReference { transaction_id: tx_hash, output_index: 1 }
  let (locked_lovelace_value, locked_lovelace_count) <-
    and_then(lovelace_value_fuzzer(min_lovelaces, max_lovelaces))
  let multisig_nft_value =
    add(zero, own_policy, multisig_token_name(input_output_ref), 1)

  let input =
    Input {
      output_reference: input_output_ref,
      output: Output {
        address: Address(Script(own_policy), None),
        value: merge(locked_lovelace_value, multisig_nft_value),
        datum: NoDatum,
        reference_script: None,
      },
    }

  let stake_key_hash <- and_then(fuzz.bytearray_fixed(28))
  let spending_limit <- and_then(fuzz.int_between(0, locked_lovelace_count))

  let number_of_signatores <- and_then(number_of_signatores_fuzzer())
  let datum <- and_then(datum_fuzzer(number_of_signatores, spending_limit))
  let output =
    Output {
      address: Address {
        payment_credential: Script(own_policy),
        stake_credential: Some(Inline(VerificationKey(stake_key_hash))),
      },
      value: locked_lovelace_value,
      datum: InlineDatum(datum),
      reference_script: None,
    }

  // No checks for signatures on burning handler
  let sorted_signers = list.sort(datum.signers, bytearray.compare)

  let burn_nft_value <-
    and_then(
      burn_multisig_fail_fuzzer(own_policy, input_output_ref, fail_points),
    )

  let transaction =
    Transaction {
      inputs: [input],
      reference_inputs: [],
      outputs: [output],
      fee: 0,
      mint: burn_nft_value,
      certificates: [],
      withdrawals: [],
      validity_range: everything,
      extra_signatories: sorted_signers |> list.unique(),
      redeemers: [],
      datums: dict.empty,
      id: tx_hash,
      votes: [],
      proposal_procedures: [],
      current_treasury_amount: None,
      treasury_donation: None,
    }

  let out_idx = 0

  fuzz.constant((own_policy, out_idx, transaction, fail_points))
}

pub fn sign_unlock_funds_multisig_fuzzer(
  min_lovelaces: Int,
  max_lovelaces: Int,
) -> Fuzzer<(MultisigDatum, OutputReference, Int, Int, Transaction)> {
  let own_policy <- and_then(fuzz.bytearray_fixed(28))
  let stake_key_hash_1 <- and_then(fuzz.bytearray_fixed(28))
  let stake_key_hash_2 <- and_then(fuzz.bytearray_fixed(28))
  let recipient_key_hash <- and_then(fuzz.bytearray_fixed(28))

  let tx_hash <- and_then(fuzz.bytearray_fixed(28))
  let input_output_ref =
    OutputReference { transaction_id: tx_hash, output_index: 1 }

  let (locked_lovelace_value, locked_lovelace_count) <-
    and_then(lovelace_value_fuzzer(min_lovelaces, max_lovelaces))
  let spending_limit <- and_then(fuzz.int_between(0, locked_lovelace_count))
  let (unlocked_lovelace_value, unlocked_lovelace_count) <-
    and_then(lovelace_value_fuzzer(0, spending_limit))
  let rest_lovelace_value =
    assets.from_lovelace(locked_lovelace_count - unlocked_lovelace_count)

  let multisig_nft_value =
    add(zero, own_policy, multisig_token_name(input_output_ref), 1)

  let number_of_signatores <- and_then(number_of_signatores_fuzzer())
  let datum <- and_then(datum_fuzzer(number_of_signatores, spending_limit))
  let own_input =
    Input {
      output_reference: input_output_ref,
      output: Output {
        address: Address(Script(own_policy), None),
        value: merge(locked_lovelace_value, multisig_nft_value),
        datum: InlineDatum(datum),
        reference_script: None,
      },
    }

  let recipient_output =
    Output {
      address: Address {
        payment_credential: VerificationKey(recipient_key_hash),
        stake_credential: Some(Inline(VerificationKey(stake_key_hash_1))),
      },
      value: unlocked_lovelace_value,
      datum: NoDatum,
      reference_script: None,
    }

  let own_output =
    Output {
      address: Address {
        payment_credential: Script(own_policy),
        stake_credential: Some(Inline(VerificationKey(stake_key_hash_2))),
      },
      value: merge(rest_lovelace_value, multisig_nft_value),
      datum: InlineDatum(datum),
      reference_script: None,
    }

  let transaction =
    Transaction {
      inputs: [own_input],
      reference_inputs: [],
      outputs: [own_output, recipient_output],
      fee: 0,
      mint: zero,
      certificates: [],
      withdrawals: [],
      validity_range: everything,
      extra_signatories: datum.signers,
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

  fuzz.constant((datum, input_output_ref, in_idx, out_idx, transaction))
}

pub fn sign_lock_funds_multisig_fuzzer(
  min_lovelaces: Int,
  max_lovelaces: Int,
) -> Fuzzer<(MultisigDatum, OutputReference, Int, Int, Transaction)> {
  let own_policy <- and_then(fuzz.bytearray_fixed(28))
  let stake_key_hash <- and_then(fuzz.bytearray_fixed(28))

  let tx_hash_1 <- and_then(fuzz.bytearray_fixed(28))
  let input_output_ref_1 =
    OutputReference { transaction_id: tx_hash_1, output_index: 1 }
  let tx_hash_2 <- and_then(fuzz.bytearray_fixed(28))
  let input_output_ref_2 =
    OutputReference { transaction_id: tx_hash_2, output_index: 1 }

  let (locked_lovelace_value, locked_lovelace_count) <-
    and_then(lovelace_value_fuzzer(min_lovelaces, max_lovelaces))
  let spending_limit <- and_then(fuzz.int_between(0, locked_lovelace_count))
  let (replenish_lovelace_value, replenish_lovelace_count) <-
    and_then(lovelace_value_fuzzer(0, spending_limit))
  let output_lovelace_value =
    assets.from_lovelace(locked_lovelace_count + replenish_lovelace_count)

  let multisig_nft_value =
    add(zero, own_policy, multisig_token_name(input_output_ref_1), 1)

  let number_of_signatores <- and_then(number_of_signatores_fuzzer())
  let datum <- and_then(datum_fuzzer(number_of_signatores, spending_limit))
  let own_input =
    Input {
      output_reference: input_output_ref_1,
      output: Output {
        address: Address(Script(own_policy), None),
        value: merge(locked_lovelace_value, multisig_nft_value),
        datum: InlineDatum(datum),
        reference_script: None,
      },
    }

  let replenish_input =
    Input {
      output_reference: input_output_ref_2,
      output: Output {
        address: Address(Script(own_policy), None),
        value: replenish_lovelace_value,
        datum: NoDatum,
        reference_script: None,
      },
    }

  let own_output =
    Output {
      address: Address {
        payment_credential: Script(own_policy),
        stake_credential: Some(Inline(VerificationKey(stake_key_hash))),
      },
      value: merge(output_lovelace_value, multisig_nft_value),
      datum: InlineDatum(datum),
      reference_script: None,
    }

  let transaction =
    Transaction {
      inputs: [own_input, replenish_input],
      reference_inputs: [],
      outputs: [own_output],
      fee: 0,
      mint: zero,
      certificates: [],
      withdrawals: [],
      validity_range: everything,
      extra_signatories: datum.signers,
      redeemers: [],
      datums: dict.empty,
      id: tx_hash_1,
      votes: [],
      proposal_procedures: [],
      current_treasury_amount: None,
      treasury_donation: None,
    }

  let in_idx = 0
  let out_idx = 0

  fuzz.constant((datum, input_output_ref_1, in_idx, out_idx, transaction))
}

pub fn sign_fail_points_fuzzer() -> Fuzzer<List<String>> {
  fuzz.set_between(
    fuzz.map(
      fuzz.pick(
        [
          @"over_limit", @"datum_changed", @"multisig_nft_amount_mint",
          @"multisig_nft_token_name", @"lost_signers",
        ],
      ),
      fn((_a, b)) { b },
    ),
    1,
    5,
  )
}

pub fn sign_multisig_fail_fuzzer(
  min_lovelaces: Int,
  max_lovelaces: Int,
) -> Fuzzer<
  (MultisigDatum, OutputReference, Int, Int, Transaction, List<String>),
> {
  let fail_points <- and_then(sign_fail_points_fuzzer())

  let own_policy <- and_then(fuzz.bytearray_fixed(28))
  let stake_key_hash_1 <- and_then(fuzz.bytearray_fixed(28))
  let stake_key_hash_2 <- and_then(fuzz.bytearray_fixed(28))
  let recipient_key_hash <- and_then(fuzz.bytearray_fixed(28))

  let tx_hash <- and_then(fuzz.bytearray_fixed(28))
  let input_output_ref =
    OutputReference { transaction_id: tx_hash, output_index: 1 }

  let (locked_lovelace_value, locked_lovelace_count) <-
    and_then(lovelace_value_fuzzer(min_lovelaces, max_lovelaces))
  let spending_limit <- and_then(fuzz.int_between(1, locked_lovelace_count))

  let (unlocked_lovelace_value, unlocked_lovelace_count) <-
    and_then(
      if list.has(fail_points, @"over_limit") {
        lovelace_value_fuzzer(spending_limit + 1, 2 * spending_limit)
      } else {
        lovelace_value_fuzzer(0, spending_limit)
      },
    )

  let rest_lovelace_value <-
    and_then(
      fuzz.constant(
        assets.from_lovelace(locked_lovelace_count - unlocked_lovelace_count),
      ),
    )

  let multisig_nft_value =
    add(zero, own_policy, multisig_token_name(input_output_ref), 1)

  let number_of_signatores <- and_then(number_of_signatores_fuzzer())
  let datum <- and_then(datum_fuzzer(number_of_signatores, spending_limit))
  let own_input =
    Input {
      output_reference: input_output_ref,
      output: Output {
        address: Address(Script(own_policy), None),
        value: merge(locked_lovelace_value, multisig_nft_value),
        datum: InlineDatum(datum),
        reference_script: None,
      },
    }

  let recipient_output =
    Output {
      address: Address {
        payment_credential: VerificationKey(recipient_key_hash),
        stake_credential: Some(Inline(VerificationKey(stake_key_hash_1))),
      },
      value: unlocked_lovelace_value,
      datum: InlineDatum(datum),
      reference_script: None,
    }

  let own_output_datum <-
    and_then(
      if list.has(fail_points, @"datum_changed") {
        datum_fuzzer(number_of_signatores, spending_limit)
      } else {
        fuzz.constant(datum)
      },
    )

  let own_output_multisig_nft_value <-
    and_then(
      mint_multisig_fail_fuzzer(own_policy, input_output_ref, fail_points),
    )

  let own_output =
    Output {
      address: Address {
        payment_credential: Script(own_policy),
        stake_credential: Some(Inline(VerificationKey(stake_key_hash_2))),
      },
      value: merge(rest_lovelace_value, own_output_multisig_nft_value),
      datum: InlineDatum(own_output_datum),
      reference_script: None,
    }

  let minimal_allowed_signers_subset =
    list.take(datum.signers |> list.unique(), datum.threshold)
  let sorted_signers <-
    and_then(lose_signers_fuzzer(minimal_allowed_signers_subset, fail_points))

  let transaction =
    Transaction {
      inputs: [own_input],
      reference_inputs: [],
      outputs: [own_output, recipient_output],
      fee: 0,
      mint: zero,
      certificates: [],
      withdrawals: [],
      validity_range: everything,
      extra_signatories: sorted_signers |> list.unique(),
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

  fuzz.constant(
    (datum, input_output_ref, in_idx, out_idx, transaction, fail_points),
  )
}

pub fn update_multisig_fuzzer(
  min_lovelaces: Int,
  max_lovelaces: Int,
) -> Fuzzer<(MultisigDatum, OutputReference, Int, Int, Transaction)> {
  let own_policy <- and_then(fuzz.bytearray_fixed(28))
  let tx_hash <- and_then(fuzz.bytearray_fixed(28))
  let input_output_ref =
    OutputReference { transaction_id: tx_hash, output_index: 1 }

  let (locked_lovelace_value, locked_lovelace_count) <-
    and_then(lovelace_value_fuzzer(min_lovelaces, max_lovelaces))
  let spending_limit <- and_then(fuzz.int_between(0, locked_lovelace_count))

  let multisig_nft_value =
    add(zero, own_policy, multisig_token_name(input_output_ref), 1)

  let number_of_signatores <- and_then(number_of_signatores_fuzzer())
  let old_datum <- and_then(datum_fuzzer(number_of_signatores, spending_limit))
  let input =
    Input {
      output_reference: input_output_ref,
      output: Output {
        address: Address(Script(own_policy), None),
        value: merge(locked_lovelace_value, multisig_nft_value),
        datum: InlineDatum(old_datum),
        reference_script: None,
      },
    }

  let updated_datum <-
    and_then(datum_fuzzer(number_of_signatores, spending_limit))
  let output =
    Output {
      address: Address {
        payment_credential: Script(own_policy),
        stake_credential: None,
      },
      value: merge(locked_lovelace_value, multisig_nft_value),
      datum: InlineDatum(updated_datum),
      reference_script: None,
    }

  let transaction =
    Transaction {
      inputs: [input],
      reference_inputs: [],
      outputs: [output],
      fee: 0,
      mint: zero,
      certificates: [],
      withdrawals: [],
      validity_range: everything,
      extra_signatories: old_datum.signers
        |> list.concat(updated_datum.signers)
        |> list.unique
        |> list.sort(bytearray.compare),
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

  fuzz.constant((old_datum, input_output_ref, in_idx, out_idx, transaction))
}

pub fn update_fail_points_fuzzer() -> Fuzzer<List<String>> {
  fuzz.set_between(
    fuzz.map(
      fuzz.pick(
        [
          @"multisig_nft_amount_mint",
          @"multisig_nft_token_name",
          @"lost_funds",
          @"lost_signers",
        ],
      ),
      fn((_a, b)) { b },
    ),
    1,
    4,
  )
}

pub fn update_multisig_fail_fuzzer(
  min_lovelaces: Int,
  max_lovelaces: Int,
) -> Fuzzer<(MultisigDatum, OutputReference, Int, Int, Transaction, List<String>)> {
  let fail_points <- and_then(update_fail_points_fuzzer())
  let own_policy <- and_then(fuzz.bytearray_fixed(28))
  let tx_hash <- and_then(fuzz.bytearray_fixed(28))
  let input_output_ref =
    OutputReference { transaction_id: tx_hash, output_index: 1 }

  let (locked_lovelace_value, locked_lovelace_count) <-
    and_then(lovelace_value_fuzzer(min_lovelaces, max_lovelaces))
  let spending_limit <- and_then(fuzz.int_between(0, locked_lovelace_count))

  let multisig_nft_value =
    add(zero, own_policy, multisig_token_name(input_output_ref), 1)

  let number_of_signatores <- and_then(number_of_signatores_fuzzer())
  let old_datum <- and_then(datum_fuzzer(number_of_signatores, spending_limit))
  let input =
    Input {
      output_reference: input_output_ref,
      output: Output {
        address: Address(Script(own_policy), None),
        value: merge(locked_lovelace_value, multisig_nft_value),
        datum: InlineDatum(old_datum),
        reference_script: None,
      },
    }

  let (own_output_lovelace_value, _count) <- and_then(if (list.has(fail_points, @"lost_funds")) {
    lovelace_value_fuzzer(0, locked_lovelace_count)
  } else {
    fuzz.constant((locked_lovelace_value, locked_lovelace_count))
  })

  let own_output_multisig_nft_value <-
    and_then(
      mint_multisig_fail_fuzzer(own_policy, input_output_ref, fail_points),
    )

  let updated_datum <-
    and_then(datum_fuzzer(number_of_signatores, spending_limit))
  let output =
    Output {
      address: Address {
        payment_credential: Script(own_policy),
        stake_credential: None,
      },
      value: merge(own_output_lovelace_value, own_output_multisig_nft_value),
      datum: InlineDatum(updated_datum),
      reference_script: None,
    }

  let minimal_allowed_signers_subset =
    list.take(list.concat(old_datum.signers, updated_datum.signers) |> list.unique(), old_datum.threshold)
  let sorted_signers <-
    and_then(lose_signers_fuzzer(minimal_allowed_signers_subset, fail_points))

  let transaction =
    Transaction {
      inputs: [input],
      reference_inputs: [],
      outputs: [output],
      fee: 0,
      mint: zero,
      certificates: [],
      withdrawals: [],
      validity_range: everything,
      extra_signatories: sorted_signers,
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

  fuzz.constant((old_datum, input_output_ref, in_idx, out_idx, transaction, fail_points))
}

pub fn remove_multisig_fuzzer(
  min_lovelaces: Int,
  max_lovelaces: Int,
) -> Fuzzer<(MultisigDatum, OutputReference, Int, Transaction)> {
  let own_policy <- and_then(fuzz.bytearray_fixed(28))
  let stake_key_hash <- and_then(fuzz.bytearray_fixed(28))
  let recipient_key_hash <- and_then(fuzz.bytearray_fixed(28))
  let tx_hash <- and_then(fuzz.bytearray_fixed(28))

  let input_output_ref =
    OutputReference { transaction_id: tx_hash, output_index: 1 }

  let (locked_lovelace_value, locked_lovelace_count) <-
    and_then(lovelace_value_fuzzer(min_lovelaces, max_lovelaces))
  let spending_limit <- and_then(fuzz.int_between(0, locked_lovelace_count))

  let multisig_nft_value =
    add(zero, own_policy, multisig_token_name(input_output_ref), 1)

  let number_of_signatores <- and_then(number_of_signatores_fuzzer())
  let datum <- and_then(datum_fuzzer(number_of_signatores, spending_limit))
  let input =
    Input {
      output_reference: input_output_ref,
      output: Output {
        address: Address(Script(own_policy), None),
        value: merge(locked_lovelace_value, multisig_nft_value),
        datum: InlineDatum(datum),
        reference_script: None,
      },
    }

  let output =
    Output {
      address: Address {
        payment_credential: VerificationKey(recipient_key_hash),
        stake_credential: Some(Inline(VerificationKey(stake_key_hash))),
      },
      value: locked_lovelace_value,
      datum: NoDatum,
      reference_script: None,
    }

  let transaction =
    Transaction {
      inputs: [input],
      reference_inputs: [],
      outputs: [output],
      fee: 0,
      mint: add(zero, own_policy, multisig_token_name(input_output_ref), -1),
      certificates: [],
      withdrawals: [],
      validity_range: everything,
      extra_signatories: datum.signers,
      redeemers: [],
      datums: dict.empty,
      id: tx_hash,
      votes: [],
      proposal_procedures: [],
      current_treasury_amount: None,
      treasury_donation: None,
    }

  let in_idx = 0

  fuzz.constant((datum, input_output_ref, in_idx, transaction))
}

pub fn test_224_01() {
  bytearray.take(blake2b_256(#"01"), 28)
}

pub fn test_224_02() {
  bytearray.take(blake2b_256(#"02"), 28)
}

pub fn test_224_03() {
  bytearray.take(blake2b_256(#"03"), 28)
}

pub fn test_224_04() {
  bytearray.take(blake2b_256(#"04"), 28)
}

pub fn test_224_05() {
  bytearray.take(blake2b_256(#"05"), 28)
}

pub fn test_224_06() {
  bytearray.take(blake2b_256(#"06"), 28)
}

pub fn test_224_07() {
  bytearray.take(blake2b_256(#"07"), 28)
}

pub fn test_policy() -> PolicyId {
  bytearray.take(blake2b_256(#"07"), 28)
}

pub fn test_wrong_policy() {
  bytearray.take(blake2b_256(#"08"), 28)
}

pub fn test_withdraw_pkh() {
  bytearray.take(blake2b_256(#"09"), 28)
}

pub fn test_input_utxo_01() {
  OutputReference { transaction_id: test_224_01(), output_index: 1 }
}

pub fn test_input_utxo_02(utxo_hash) {
  OutputReference { transaction_id: utxo_hash, output_index: 1 }
}

pub fn test_multisig_datum(signitories, signer_count, limit_qty) {
  MultisigDatum {
    signers: signitories,
    threshold: signer_count,
    fund_policy_id: ada_policy_id,
    fund_asset_name: ada_asset_name,
    spending_limit: limit_qty,
  }
}

pub fn test_context_input_01(output_ref, own_cs, token_value, datum) {
  Input {
    output_reference: output_ref,
    output: Output {
      address: Address(Script(own_cs), None),
      value: token_value,
      datum: InlineDatum(datum),
      reference_script: None,
    },
  }
}

pub fn test_context_input_02(output_ref, own_cs, minted_value, datum) {
  Input {
    output_reference: output_ref,
    output: Output {
      address: Address(Script(own_cs), None),
      value: add(minted_value, ada_policy_id, ada_asset_name, 4_000_000),
      datum: InlineDatum(datum),
      reference_script: None,
    },
  }
}

pub fn test_utxo_02(own_cs, minted_value, lovelace, datum) {
  Output {
    address: Address {
      payment_credential: Script(own_cs),
      stake_credential: None,
    },
    value: add(minted_value, ada_policy_id, ada_asset_name, lovelace),
    datum: InlineDatum(datum),
    reference_script: None,
  }
}

pub fn test_user_utxo(pubkey_hash: ByteArray, token_value, datum) {
  Output {
    address: Address {
      payment_credential: VerificationKey(pubkey_hash),
      stake_credential: None,
    },
    value: token_value,
    datum: InlineDatum(datum),
    reference_script: None,
  }
}

pub fn test_spend_transaction(
  main_inputs,
  ref_inputs,
  main_outputs,
  minted_value,
  time_range,
  tx_hash: ByteArray,
) {
  Transaction {
    inputs: main_inputs,
    reference_inputs: ref_inputs,
    outputs: main_outputs,
    fee: 0,
    mint: minted_value,
    certificates: [],
    withdrawals: [],
    validity_range: time_range,
    extra_signatories: [],
    redeemers: [],
    datums: dict.empty,
    id: tx_hash,
    votes: [],
    proposal_procedures: [],
    current_treasury_amount: None,
    treasury_donation: None,
  }
}
