use aiken/transaction.{ScriptContext}
use upgradable_multisig/multisig/validation.{validate_sign, validate_update}
use upgradable_multisig/types.{MultisigDatum, MultisigRedeemer, Sign, Update}

// TODO: Consult Mark/ Jonathan on the assumption of a single authentic utxo's viability
// Main validator function for the upgradable multisig contract
validator {
  fn multisig_validator(
    datum: MultisigDatum,
    redeemer: MultisigRedeemer,
    context: ScriptContext,
  ) -> Bool {
    when redeemer is {
      Sign { input_index, output_index } ->
        validate_sign(datum, input_index, output_index, context)
      Update { input_index, output_index } ->
        validate_update(datum, input_index, output_index, context)
    }
  }
}
