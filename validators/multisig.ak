use cardano/assets.{PolicyId}
use cardano/transaction.{OutputReference, Transaction}
use upgradable_multisig/multisig/validation.{
  validate_initiate_multisig, validate_multisig_end, validate_remove,
  validate_sign, validate_update,
}
use upgradable_multisig/types.{
  EndMultiSig, InitMultiSig, MintMultisig, MultisigDatum, MultisigRedeemer,
  Remove, Sign, Update,
}

// Main validator function for the upgradable multisig contract
validator multisig {
  mint(r: MintMultisig, policy_id: PolicyId, self: Transaction) {
    when r is {
      InitMultiSig { output_reference, input_index } ->
        validate_initiate_multisig(
          policy_id,
          output_reference,
          input_index,
          self,
        )

      EndMultiSig { input_index } ->
        validate_multisig_end(policy_id, input_index, self)
    }
  }

  spend(
    d: Option<MultisigDatum>,
    r: MultisigRedeemer,
    own_ref: OutputReference,
    self: Transaction,
  ) {
    when r is {
      Sign { input_index, output_index } ->
        validate_sign(d, Pair(input_index, output_index), own_ref, self)
      Update { input_index, output_index } ->
        validate_update(d, Pair(input_index, output_index), own_ref, self)
      Remove { input_index, output_index } ->
        validate_remove(d, Pair(input_index, output_index), own_ref, self)
    }
  }

  else(_) {
    fail
  }
}
