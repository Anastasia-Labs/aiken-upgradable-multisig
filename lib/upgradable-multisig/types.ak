use aiken/crypto.{Blake2b_224, Hash, VerificationKey}
use cardano/assets.{AssetName, PolicyId}

pub type PubKeyHash =
  Hash<Blake2b_224, VerificationKey>

pub type MultisigDatum {
  signers: List<PubKeyHash>,
  threshold: Int,
  fund_policy_id: PolicyId,
  fund_asset_name: AssetName,
  spending_limit: Int,
}

pub type MintMultisig {
  InitMultiSig { output_index: Int }
  EndMultiSig
}

pub type MultisigRedeemer {
  Sign { input_index: Int, output_index: Int }
  Update { input_index: Int, output_index: Int }
  Remove { input_index: Int }
}
