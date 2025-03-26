use upgradable_multisig/multisig/validation.{
  validate_end, validate_init, validate_remove, validate_sign, validate_update,
}
use upgradable_multisig/tests/tests

test succeed_init_multisig_fuzzy(
  test_values via tests.init_multisig_fuzzer(1_000_000, 1_000_000_000),
) {
  let (own_policy, own_ref, idx, transaction) = test_values

  validate_init(own_policy, own_ref, idx, transaction)
}

test fail_init_multisig_fuzzy(
  test_values via tests.init_multisig_fail_fuzzer(1_000_000, 1_000_000_000),
) fail {
  let (own_policy, own_ref, idx, transaction, _fail_points) = test_values
  validate_init(own_policy, own_ref, idx, transaction)
}

test succeed_end_multisig_fuzzy(
  test_values via tests.end_multisig_fuzzer(1_000_000, 1_000_000_000),
) {
  let (own_policy, idx, transaction) = test_values
  validate_end(own_policy, idx, transaction)
}

test fail_end_multisig_fuzzy(
  test_values via tests.end_multisig_fail_fuzzer(1_000_000, 1_000_000_000),
) fail {
  let (own_policy, idx, transaction, _fail_points) = test_values
  validate_end(own_policy, idx, transaction)
}

test succeed_sign_unlock_multisig_fuzzy(
  test_values via tests.sign_unlock_funds_multisig_fuzzer(
    1_000_000,
    1_000_000_000,
  ),
) {
  let (datum, input_output_ref, in_idx, out_idx, transaction) = test_values
  validate_sign(datum, input_output_ref, in_idx, out_idx, transaction)
}

test succeed_sign_lock_multisig_fuzzy(
  test_values via tests.sign_lock_funds_multisig_fuzzer(
    1_000_000,
    1_000_000_000,
  ),
) {
  let (datum, input_output_ref, in_idx, out_idx, transaction) = test_values
  validate_sign(datum, input_output_ref, in_idx, out_idx, transaction)
}

test fail_sign_multisig_fuzzy(
  test_values via tests.sign_multisig_fail_fuzzer(1_000_000, 1_000_000_000),
) fail {
  let (datum, input_output_ref, in_idx, out_idx, transaction, _fail_points) =
    test_values
  validate_sign(datum, input_output_ref, in_idx, out_idx, transaction)
}

test succeed_update_multisig_fuzzy(
  test_values via tests.update_multisig_fuzzer(1_000_000, 1_000_000_000),
) {
  let (datum, input_output_ref, in_idx, out_idx, transaction) = test_values
  validate_update(datum, input_output_ref, in_idx, out_idx, transaction)
}

test fail_update_multisig_fuzzy(
  test_values via tests.update_multisig_fail_fuzzer(1_000_000, 1_000_000_000),
) fail {
  let (datum, input_output_ref, in_idx, out_idx, transaction, _fail_points) =
    test_values
  validate_update(datum, input_output_ref, in_idx, out_idx, transaction)
}

test succeed_remove_multisig_fuzzy(
  test_values via tests.remove_multisig_fuzzer(1_000_000, 1_000_000_000),
) {
  let (datum, input_output_ref, in_idx, transaction) = test_values
  validate_remove(datum, input_output_ref, in_idx, transaction)
}

test fail_remove_multisig_fuzzy(
  test_values via tests.remove_multisig_fail_fuzzer(1_000_000, 1_000_000_000),
) fail {
  let (datum, input_output_ref, in_idx, transaction, _fail_points) = test_values
  validate_remove(datum, input_output_ref, in_idx, transaction)
}
