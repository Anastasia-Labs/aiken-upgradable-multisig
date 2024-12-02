use aiken/collection/list
use upgradable_multisig/types.{MultisigDatum, PubKeyHash}

pub fn validate_multisig_datum(datum: MultisigDatum) -> Bool {
  let signers_nr = list.length(datum.signers)
  (signers_nr >= datum.threshold)? && (datum.threshold > 0)? && (datum.spending_limit > 2_000_000)?
}

fn has_enough_signers(
  all_signers: List<PubKeyHash>,
  threshold: Int,
  actual_signers: List<PubKeyHash>,
) -> Bool {
  when all_signers is {
    [] -> False
    [head, ..tail] ->
      if list.has(actual_signers, head) {
        if threshold > 1 {
          has_enough_signers(tail, threshold - 1, actual_signers)
        } else {
          True
        }
      } else {
        has_enough_signers(tail, threshold, actual_signers)
      }
  }
}

pub fn signed_within_threshold(
  datum: MultisigDatum,
  extra_signatories: List<PubKeyHash>,
) -> Bool {
  has_enough_signers(datum.signers, datum.threshold, extra_signatories)
}
