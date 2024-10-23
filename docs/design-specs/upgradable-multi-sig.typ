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
      #counter(page).display( "1/1",both: true)]
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
#v(20pt)
\

#set heading(numbering: "1.")
#show heading: set text(rgb("#c41112"))

= Overview
\

This document outlines the design specification for an upgradable multisignature (multisig) smart contract implemented using Aiken for the Cardano blockchain. The contract enables authorized members to execute asset transactions within predefined thresholds, demonstrates secure spending of assets, allows seamless adjustment of signer thresholds, and supports dynamic addition or removal of signers for enduring usability and adaptability.

#pagebreak()

= Architecture
\
There are one main contracts in this multi-sig system.

+ *Multisig Validator* 
  
  This is the core contract responsible for handling the logic for:

  - Managing authorized signers

  - Validating and executing transactions
  - Handling contract upgrades
  - Verifying signatures and authenticating transactions


// + *Multisig Policy*
  
// This contract  plays a key role in maintaining the uniqueness and integrity of each multi-sig setup by:

//   - Minting a non-fungible identification token that must always be present in the Multi-sig Validator UTxO.

//   - Controlling the minting process to ensure it only occurs during legitimate setup

#pagebreak()

= Specification

\
== System Actors
\ 
- *Signers*
  
  Entities who are authorized to sign transactions, participate in the management of the multi-sig wallet, and approve changes to the signer list or thresholds.

- *Initiator*

  The entity who creates the initial multi-sig wallet setup, defining the initial set of signers and thresholds.

\
== Tokens
\
- None

#pagebreak()

== Smart Contracts
\
=== Multi-sig validator
\
The Multi-sig Contract is the primary contract responsible for managing the list of authorized signers, validating transactions, and ensuring the proper execution of multi-sig operations.

==== Parameters
\
- None
\
==== Spend Purpose
\
The contract uses the Spend purpose, allowing it to manage and spend funds locked in its address.

==== Datum
\
The datum structure holds the current state of the multisig arrangement:
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
- Sign: For executing fund transfers

- Update: For modifying the multisig configuration
\
==== Validation
\
+ *Sign* 
  
  The redeemer allows a majority of the authorized signers to collectively approve and execute transactions using the funds controlled by the multi-signature contract
  
  - Verifies that the required number of authorized signers have signed the transaction

  - Ensures the transfer amount does not exceed the spending limit

  - Checks that the total value is preserved across inputs and outputs
  
  - Ensure the output datum matches the input datum (no changes to the multisig configuration)

+ *Update* 

  The redeemer enables the modification of the multi-signature arrangement itself.
 
  - Verifies that the required number of authorized signers have signed the transaction 

  - Enforce bounds on new signers list and threshold:

    - New signer count must be greater than 0

    - New threshold must be greater than 0 and less than or equal to the new signer count

    - New funds quantity must be greater than or equal to 0

    - New spending limit must be greater than or equal to 0 and less than or equal to the new funds quantity

  - Ensure there are no duplicate keys in the new list of signers

  - Verify that input value equals output value (no spending during update)

  - Verify that the total value is preserved (input value equals output value, no funds are spent during update)

  - Ensure the new configuration is stored in the output datum

  - Allows addition or removal of only one signer at a time

\
#pagebreak()

= Transactions
\
This section outlines the various transactions involved in the Upgradable Multi-Signature Contract on the Cardano blockchain.
\
  === Spend :: Sign
\

This action ensures that the number of signers meets or exceeds the specified threshold and The datum of the Multisig remains the same.

\
#transaction(
  "Sign",
  inputs: (
    (
      name: "Mulitsig UTxO",
      address: "multisig_contract",
      value: (
        ada: 100000,
      ),
      datum: (
        a: "signers",
        b: "threshold",
        c: "funds",
        e: "spending_limit",
      )
    ),
  ),
  outputs: (
    (
      name: "Withdrawal UTxO",
      value: (
        ada: 1000,
      )
    ),
    (
      name: "Mulitsig Output",
      address: "multisig_contract",
      value: (
        ada: 99000,
       
      ),
      datum: (
        a: "signers",
        b: "threshold",
        c: "funds",
        e: "spending_limit",
      )
    ),
  ),
  signatures: (
    "Signer A",
    "Signer B",
    "Signer C",
  ),
  // certificates: (
  //   "Withdraw Stake A",
  // ),
  show_mints: false,
  notes: [Sign UTxO Diagram]
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

=== Spend :: Update
  \

Allows for the addition or removal of members from the Multisig arrangement, and
updates the required signers threshold.

  \
  #transaction(
  "Sign",
  inputs: (
    (
      name: "Mulitsig UTxO",
      address: "multisig_contract",
      value: (
        ada: 100000,
      ),
      datum: (
        a: "old_signers",
        b: "old_threshold",
        c: "funds",
        e: "spending_limit",
  )
    ),
  ),
  outputs: (
   
    (
      name: "Mulitsig Output",
      address: "multisig_contract",
      value: (
        ada: 100000,
       
      ),
      datum: (
        a: "new_signers",
        b: "new_threshold",
        c: "funds",
        e: "spending_limit",

      )
    ),
  ),
  signatures: (
    "Signer A",
    "Signer B",
    "Signer C",
  ),
  show_mints: false,
  notes: [Update UTxO Diagram]
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

