use aiken/hash.{Blake2b_224, Hash}
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
}

pub type MultisigRedeemer {
  Sign { input_index: Int, output_index: Int }
  Update { input_index: Int, output_index: Int }
}
