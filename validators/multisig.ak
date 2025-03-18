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

validator multisig {
  mint(r: MintMultisig, own_policy: PolicyId, tx: Transaction) {
    when r is {
      InitMultiSig { output_reference, output_index } ->
        validate_initiate_multisig(
          own_policy,
          output_reference,
          output_index,
          tx,
        )

      EndMultiSig { input_index } ->
        validate_multisig_end(own_policy, input_index, tx)
    }
  }

  spend(
    datum_option: Option<MultisigDatum>,
    redeemer: MultisigRedeemer,
    output_reference: OutputReference,
    tx: Transaction,
  ) {
    expect Some(d) = datum_option
    when redeemer is {
      Sign { input_index, output_index } ->
        validate_sign(d, output_reference, input_index, output_index, tx)
      Update { input_index, output_index } ->
        validate_update(d, output_reference, input_index, output_index, tx)
      Remove { input_index } ->
        validate_remove(d, output_reference, input_index, tx)
    }
  }

  else(_) {
    fail
  }
}
