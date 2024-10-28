use aiken/transaction.{Mint, ScriptContext}
use upgradable_multisig/multisig/validation.{
  validate_initiate_multisig, validate_multisig_end, validate_sign,
  validate_update,
}
use upgradable_multisig/types.{
  EndMultiSig, InitMultiSig, MintMultisig, MultisigDatum, MultisigRedeemer, Sign,
  Update,
}

// TODO: Consult Mark/ Jonathan on the assumption of a single authentic utxo's viability
// Main validator function for the upgradable multisig contract
validator {
  fn multisig_policy(r: MintMultisig, ctx: ScriptContext) -> Bool {
    let ScriptContext { transaction: tx, purpose } = ctx
    expect Mint(own_policy) = purpose

    when r is {
      InitMultiSig { output_reference, input_index, output_index } ->
        validate_initiate_multisig(
          own_policy,
          output_reference,
          input_index,
          output_index,
          tx,
        )?

      EndMultiSig { datum, input_index } ->
        validate_multisig_end(datum, own_policy, input_index, tx)
    }
  }

  fn multisig_validator(
    d: MultisigDatum,
    r: MultisigRedeemer,
    ctx: ScriptContext,
  ) -> Bool {
    when r is {
      Sign { input_index, output_index } ->
        validate_sign(d, input_index, output_index, ctx)
      Update { input_index, output_index } ->
        validate_update(d, input_index, output_index, ctx)
    }
  }
}
