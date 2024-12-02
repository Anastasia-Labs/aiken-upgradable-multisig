#import "@preview/cetz:0.2.2"
#import "./resources/transaction.typ": *

#let image-background = image("../images/background-1.jpg", height: 100%, fit: "cover")
#let image-foreground = image("../images/Logo-Anastasia-Labs-V-Color02.png", width: 100%, fit: "contain")
#let image-header = image("../images/Logo-Anastasia-Labs-V-Color01.png", height: 75%, fit: "contain")
#let fund-link = link("https://projectcatalyst.io/funds/10/f10-osde-open-source-dev-ecosystem/anastasia-labs-the-trifecta-of-data-structures-merkle-trees-tries-and-linked-lists-for-cutting-edge-contracts")[Catalyst Proposal]
#let git-link = link("https://github.com/Anastasia-Labs/data-structures")[Main Github Repo]

#set page(
  background: image-background,
  paper :"a4",
  margin: (left : 20mm,right : 20mm,top : 40mm,bottom : 30mm)
)

// Set default text style
#set text(15pt, font: "Montserrat")

#v(3cm) // Add vertical space

#align(center)[
  #box(
    width: 60%,
    stroke: none,
    image-foreground,
  )
]

#v(1cm) // Add vertical space

// Set text style for the report title
#set text(20pt, fill: white)

// Center-align the report title
#align(center)[#strong[Upgradable Multi-Signature Contract]]
#align(center)[#strong[Project Design Specification]]

#v(5cm)

// Set text style for project details
#set text(13pt, fill: white)


// Reset text style to default
#set text(fill: luma(0%))

// Display project details
#show link: underline
#set terms(separator:[: ],hanging-indent: 18mm)

#set par(justify: true)
#set page(
  paper: "a4",
  margin: (left: 20mm, right: 20mm, top: 40mm, bottom: 35mm),
  background: none,
  header: [
    #align(right)[
      #image("../images/Logo-Anastasia-Labs-V-Color01.png", width: 25%, fit: "contain")
    ]
    #v(-0.5cm)
    #line(length: 100%, stroke: 0.5pt)
  ],
)

#v(20mm)
#show link: underline
#show outline.entry.where(level: 1): it => {
  v(6mm, weak: true)
  strong(it)
}

#outline(depth:3, indent: 1em)
#pagebreak()
#set text(size: 11pt)  // Reset text size to 10pt
#set page(
   footer: [
    #line(length: 100%, stroke: 0.5pt)
    #v(-3mm)
    #align(center)[ 
      #set text(size: 11pt, fill: black)
      *Anastasia Labs – *
      #set text(size: 11pt, fill: gray)
      *Upgradable Multi-Signature Contract*
      #v(-3mm)
      Project Design Specification
      #v(-3mm)
    ]
    #v(-6mm)
    #align(right)[
      #context counter(page).display( "1/1",both: true)]
  ] 
)

// Initialize page counter
#counter(page).update(1)
#v(100pt)
// Display project details
// #set terms(separator:[: ],hanging-indent: 18mm)
// #align(center)[
//   #set text(size: 20pt)
//   #strong[Upgradable Multi-Signature Contract]]
// #v(20pt)
\

#set heading(numbering: "1.")
#show heading: set text(rgb("#c41112"))

= Overview
\

The Upgradable Multi-Signature Smart Contract is developed using Aiken and is designed to facilitate collaborative management of funds and operations on the Cardano blockchain. This contract allows multiple authorized signers to collectively approve and execute transactions, manage funds, and update the multi-sig configuration (such as adding or removing signers or changing the signature threshold).

The contract ensures secure and efficient transactions by through the validation of signatories, enforcing spending limits, and allowing for updates to the signer list and thresholds within a decentralized framework.


#pagebreak()
#v(50pt)

\
= Architecture
\
#figure(
  image("../images/Multisig-Architecture.png", width: 100%),
  caption: [Upgradable Multisig Architecture],
)
\

The architecture consists of a single multi-validator contracts that manages the mulit-signature functionality in this system.

\
+ *Multisig Contract* 
  
  This is the core contract responsible for handling the logic for:

  - Managing authorized signers

  - Validating and executing transactions
  - Handling contract upgrades
  - Verifying signatures and authenticating transactions

#pagebreak()
#v(50pt)

\
= Specification

\
== System Actors
\ 
- *Initiator*

  The entity who creates the initial multi-sig wallet setup, defining the initial set of signers and thresholds. The initiator initiates the multi-sig with the datum and mints an Multisig NFT.


- *Signers*
  
  Entities who are authorized to sign transactions, participate in the management of the multi-sig wallet, and approve changes to the signer list or thresholds. Authorization is based on their inclusion in the signers list within the contract's datum.

\
== Tokens
\
- *Multisig NFT*

  A unique Non-Fungible Token (NFT) representing the state and authority of the multi-sig contract. The Multisig NFT ensures the uniqueness and integrity of the contract's UTxO and is used to control access and operations within the contract.

  - *Token Name:* Derived from the transaction hash (TxHash) and output index (TxIx) of the UTXO where the NFT is initially minted.


#pagebreak()
#v(50pt)

\
== Smart Contracts
\
=== Multisig Multi-validator
\
The Multi-sig Contract is the primary contract responsible for managing the list of authorized signers, validating transactions, and ensuring the proper execution of multi-sig operations using the multisig NFT.

==== Parameters
\
- None


==== Mint Purpose
\
===== Redeemer
\

```t
  pub type MintMultisig {
    InitMultiSig {
      output_reference: OutputReference,
      input_index: Int,
      output_index: Int,
    }
    EndMultiSig { datum: MultisigDatum, input_index: Int }
  }

```
\
- *InitMultiSig:* Creates a new multi-sig setup by minting exactly one Multisig NFT.

- *EndMultiSig:* Terminates a multi-sig setup by burning exactly one Multisig NFT.

\
===== Validation
\

+ *InitMultiSig*

  Allows the initiator to create a new multi-sig setup by minting exactly one Multisig NFT.

  - Validate that out_ref (output reference) must be present in the transaction inputs.
  
  - Validate that the redeemer mints exactly one Multisig NFT with the correct token name derived from the UTXO.
  - Ensure that the Multisig NFT is locked at the Multi-Sig Validator script address.
  - Validate that the initial datum is correctly set with the signers, threshold, and other configuration parameters.
  \
+ *EndMultiSig:* 

  Allows the authorized signers to terminate the multi-sig contract by burning the Multisig NFT.

  - Verify that the required number of authorized signers have signed the transaction.

  - Ensure that the Multisig NFT is present in the input and is being burned in the transaction.
  - Confirm that all funds are appropriately distributed upon termination.

#pagebreak()
#v(50pt)

\
==== Spend Purpose
\
The contract uses the Spend purpose, allowing it to handle spending operations such as signing transactions and updating the multi-sig configuration.

==== Datum
\
The multisig datum structure holds the current state of the multisig arrangement:

```t

  pub type MultisigDatum {
    signers: List<PubKeyHash>,
    threshold: Int,
    funds: AssetClass,
    spending_limit: Int,
  }

```
 \
- *`signers`:* List of public key hashes of authorized signers.

- *`threshold`:* Minimum number of required signatures.

- *`funds`:* AssetClass of the funds to be withdrawn.

- *`spending_limit`:* Max Amount of funds to be withdrawn per transaction.

\
==== Redeemer
\
The contract supports two types of operations, represented by the redeemer:
\

```t

  pub type MultisigRedeemer {
    Sign { input_index: Int, output_index: Int }
    Update { input_index: Int, output_index: Int }
  }

```
\
- *Sign:* For executing fund transfers

- *Update:* For modifying the multisig configuration
\
==== Validation
\
+ *Sign* 
  
  The redeemer allows a majority of the authorized signers to collectively approve and execute transactions using the funds controlled by the multi-signature contract
  
  - Verifies that the required number of authorized signers have signed the transaction (based on the threshold).

  - Ensures the transfer amount does not exceed the `spending_limit`

  - Checks that the Multisig NFT remains at the script address in the output.

  - Checks that the total value is preserved across inputs and outputs (excluding the spent amount).
  
  - Ensure the output datum matches the input datum (no changes to the multisig configuration)
  \
+ *Update* 

  The redeemer enables the modification of the multi-signature arrangement itself.
 
  - Verifies that the required number of authorized signers have signed the transaction 

  - Enforce bounds on new signers list and threshold:

    - New signer count must be greater than 0

    - New threshold must be greater than 0 and less than or equal to the new signer count

    - New spending limit must be greater than or equal to 0 and less than or equal to the new funds quantity

    - Ensure there are no duplicate keys in the new list of signers

  - Validates that the Multisig NFT remains at the script address in the output.

  - Verify that input value equals output value (no spending during update)

  - Verify that the total value is preserved (input value equals output value, no funds are spent during update)

  - Ensure the new configuration is stored in the output datum

\
#pagebreak()
#v(50pt)

\
= Transactions
\
This section outlines the various transactions involved in the Upgradable Multi-Signature Contract on the Cardano blockchain.

\
== Mint :: InitMultiSig
\
This transaction initializes the multi-sig contract by minting the Multisig NFT and setting up the initial configuration.

\
#transaction(
  "InitMultiSig",
  inputs: (
    (
      name: "Initiator UTxO",
      address: "initiator_wallet",
      value: (
        ada: 1000000,
      ),
    ),
  ),
  outputs: (
    (
      name: "Multisig Validator UTxO",
      address: "multisig_validator",
      value: (
        ada: 1000000,
        Multisig_NFT: 1,
      ),
      datum: (
        signers: (`Signer A`, `Signer B`, `Signer C`, `Signer D`),
        threshold: 2,
        spending_limit: `500000`,
        transaction_limit_value: (ada: `1000000`),
      ),
    ),
    (
      name: "Initiator Change UTxO",
      address: "initiator_wallet",
      value: (
        ada: 0, // Remaining ADA after fees (for illustration)
      ),
    ),
  ),
  signatures: (
    "Initiator",
  ),
  show_mints: true,
  notes: [Initiate MultiSig Transaction],
)

\
=== Inputs
\
+ *Initiator Wallet UTxO*

  - Address: Initiator's wallet address

  - Value:

    - Minimum ADA required

    - Any additional ADA required for the transaction
\
=== Mints
\
+ *Multi-Sig Validator*

  - Redeemer: InitMultiSig

  - Value:

    - +1 Multisig NFT Asset
\
=== Outputs
\
+ *Multi-Sig Validator UTxO*

  - Address: Multi-Sig Validator script address

  - Datum:

    - signers: 4.

    - threshold: 2.
    - spending_limit: 500,000 ADA.
    - transaction_limit_value: Asset class and quantity defining the limit for transactions.

  - Value:

    - Minimum ADA required

    - 1 Multisig NFT Asset
\
+ *Initiator Change UTxO* (optional)

  - Address: Initiator's wallet address
  - Value:
    - Remaining ADA after transaction fees

#pagebreak()
#v(50pt)
\
== Mint :: EndMultiSig

\
This transaction terminates the multi-sig contract by burning the Multisig NFT and distributing the remaining funds.

\
#transaction(
  "EndMultiSig",
  inputs: (
    (
      name: "Multisig Validator UTxO",
      address: "multisig_validator",
      value: (
        ada: 1000000,
        Multisig_NFT: 1,
      ),
      datum: (
        signers: (`Signer A`, `Signer B`, `Signer C`),
        threshold: 2,
        spending_limit: `500000`,
        transaction_limit_value: (ada: `1000000`),
      ),
      // redeemer: "EndMultiSig",
    ),
  ),
  outputs: (
    (
      name: "Signer A UTxO",
      address: "signer_A_wallet",
      value: (
        ada: 250000,
      ),
    ),
    (
      name: "Signer B UTxO",
      address: "signer_B_wallet",
      value: (
        ada: 250000,
      ),
    ),
    (
      name: "Signer C UTxO",
      address: "signer_C_wallet",
      value: (
        ada: 250000,
      ),
    ),
     (
      name: "Signer D UTxO",
      address: "signer_D_wallet",
      value: (
        ada: 250000,
      ),
    ),
  ),
  signatures: (
    "Signer A",
    "Signer B",
  ),
  show_mints: true,
  notes: [End MultiSig Transaction],
)
\

\
=== Inputs
\
+ *Multi-Sig Validator UTxO*

  - Address: Multi-Sig Validator script address
  - Datum:
    - Current multi-sig configuration

  - Value:
    - Minimum ADA

    - 1 Multisig NFT Asset
    - Any remaining funds managed by the contract
  \
+ *Signers' Signatures*

  Required number of signers (as per threshold) must sign the transaction.

=== Mints
\
+ *Multi-Sig Validator*

  - Redeemer: EndMultiSig

  - Value:
  - −1 Multisig NFT Asset (burning the NFT)
\
=== Outputs
\
+ Distribution UTxOs

  - Funds are distributed to the appropriate addresses as per the termination plan.

  - Value:
  
    - ADA and other assets as needed

#pagebreak()
#v(50pt)
\
== Spend :: Sign
\

This transaction ensures that the number of signers meets or exceeds the specified threshold and The datum of the Multisig remains the same.

\
#transaction(
  "Sign",
  inputs: (
    (
      name: "Multisig Validator UTxO",
      address: "multisig_validator",
      value: (
        ada: 1000000,
        Multisig_NFT: 1,
      ),
      datum: (
        signers: (`Signer A`, `Signer B`, `Signer C`),
        threshold: 2,
        spending_limit: `500000`,
        transaction_limit_value: (ada: `1000000`),
      ),
      // redeemer: "Sign",
    ),
  ),
  outputs: (
    (
      name: "Recipient UTxO",
      address: "recipient_wallet",
      value: (
        ada: 500000, // Transfer amount
      ),
    ),
    (
      name: "Multisig Validator UTxO",
      address: "multisig_validator",
      value: (
        ada: 500000, // Remaining funds
        Multisig_NFT: 1,
      ),
      datum: (
        signers: (`Signer A`, `Signer B`, `Signer C`),
        threshold: 2,
        spending_limit: `500000`,
        transaction_limit_value: (ada: `1000000`),
      ),
    ),
  ),
  signatures: (
    "Signer A",
    "Signer B",
  ),
  show_mints: false,
  notes: [Sign Transaction],
)

\

==== Inputs
\

  + *Multisig Validator UTxO*

    - Address: Multisig validator script address

    - Datum:

      - `signers`
      - `threshold`
      - `funds`
      - `spending_limit`
.
    - Value:

      - ADA + Any tokens
      - Locked Value

\
==== Outputs
\
  + *Recipient Wallet UTxO*
    - Address: Recipient wallet address

      - Transferred ADA/tokens

  + *Multisig Validator UTxO:*
    - Address: Multisig validator script address

    - Datum:

      - `signers`
      - `threshold`
      - `funds`  
      - `spending_limit`  
      
    - Value:

      - Remaining ADA + Remaining tokens

#pagebreak()
#v(50pt)
\
== Spend :: Update
\

Allows for the addition or removal of members from the Multisig arrangement, and
updates the required signers threshold.

  \
  #transaction(
  "Update",
  inputs: (
    (
      name: "Multisig Validator UTxO",
      address: "multisig_validator",
      value: (
        ada: 1000000,
        Multisig_NFT: 1,
      ),
      datum: (
        signers: (`Signer A`, `Signer B`, `Signer C`),
        threshold: 2,
        spending_limit: `500000`,
        transaction_limit_value: (ada: `1000000`),
      ),
      // redeemer: "Update",
    ),
  ),
  outputs: (
    (
      name: "Multisig Validator UTxO",
      address: "multisig_validator",
      value: (
        ada: 1000000,
        Multisig_NFT: 1,
      ),
      datum: (
        signers: (`Signer A`, `Signer B`, `Signer D`), // Updated signers list
        threshold: 3,
        spending_limit: `500000`,
        transaction_limit_value: (ada: `1000000`),
      ),
    ),
  ),
  signatures: (
    "Signer A",
    "Signer B",
  ),
  show_mints: false,
  notes: [Update Multisig Configuration],
)

\

==== Inputs
\

  + *Multisig Validator UTxO*

    - Address: Multisig validator script address

    - Datum:

      - `old_signers`
      - `old_threshold`
      - `funds`
      - `old_spending_limit`

    - Value:

      - X ADA + Any tokens

\
==== Outputs
\
  + *Multisig Wallet UTxO*

    - Address: Merchant wallet address
    - Datum:

      - `new_signers`
      - `new_threshold`
      - `funds`
      - `new_spending_limit`

    - Value: 

      - X ADA + Any tokens (unchanged)

