use aiken/hash.{Blake2b_224, Hash}
use aiken/transaction.{OutputReference}
use aiken/transaction/credential.{VerificationKey}

pub type PubKeyHash =
  Hash<Blake2b_224, VerificationKey>

pub type AssetClass {
  policy_id: ByteArray,
  asset_name: ByteArray,
}

pub type MultisigDatum {
  signers: List<PubKeyHash>,
  threshold: Int,
  funds: AssetClass,
  spending_limit: Int,
  minimum_ada: Int,
}

pub type MultisigRedeemer {
  Sign { input_index: Int, output_index: Int }
  Update { input_index: Int, output_index: Int }
  Remove { input_index: Int, output_index: Int }
}

pub type MintMultisig {
  InitMultiSig { output_reference: OutputReference, input_index: Int }
  EndMultiSig { input_index: Int }
}
