# Upgradable Multi-Signature Contract

## Overview

The Upgradable Multi-Signature Contract is designed for secure and collaborative management of funds on the Cardano blockchain. It allows multiple authorized signers to collectively authorize transactions, ensuring that funds can only be moved with the required approvals. Key features include:

- **Multi-Signature Wallet Setup:** Establish a multi-signature wallet with a customizable list of authorized signers.

- **Flexible Thresholds:** Define a threshold for the minimum number of signatures required to approve transactions.

- **Signer Management:** Update the list of signers and the signature threshold as needed, allowing for the addition or removal of signers.

- **Spending Limits Enforcement:** Set and enforce spending limits for transactions to prevent unauthorized or excessive withdrawals.

- **Unique Contract Identification:** Utilize a unique Multisig NFT to ensure the integrity and uniqueness of the contract's state and prevent replay attacks.

## Design Documentation

For a comprehensive understanding of the contract's architecture, design
decisions, and implementation details, please refer to the
[Design Documentation](/docs/design-specs/upgradable-multi-sig.pdf). This
documentation provides in-depth insights into the contract's design, including
its components, transaction flows, the role of the Multisig NFT and detailed explanations of all the functionalities.

## Contract Functionality

### Validator Function

The multisig_validator is the core component of the contract, responsible for:

1. **Signature Validation:** Checks if the number of valid signatures meets or exceeds the required threshold for a transaction to be approved.

2. **Spending Limit Enforcement:** Ensures that transactions adhere to the spending limits specified in the contract's configuration.
3. **State Integrity with Multisig NFT:** Manages the Multisig NFT to maintain the uniqueness and integrity of the contract's UTXO (Unspent Transaction Output).
4. **Datum Validation:** Validates that the contract's datum (state data) is correctly updated during transactions, preventing unauthorized changes.

### Key Functions

1. **`validate_init:`** Validates the initialization of the multisig contract, ensuring that the Multisig NFT is correctly minted and that the initial configuration is properly set.

2. **`validate_end:`** Validates the termination of the multisig contract, confirming that the required signers have approved the termination and that the Multisig NFT is correctly burned.

3. **`validate_sign:`** Validates transactions that involve spending funds from the multisig contract. It ensures:

   - The transaction has the required number of valid signatures.

   - The amount being transferred does not exceed the defined spending limit.
   - The Multisig NFT remains at the script address, maintaining the contract's integrity.
   - The contract's datum remains unchanged unless explicitly allowed.

4. **`validate_update:`** Validates updates to the contract's configuration, such as changes to the list of signers or the signature threshold. It ensures:

   - The update is authorized by the required number of signers.

   - The new configuration adheres to the contract's rules (e.g., threshold is within valid bounds).
   - There are no duplicate signers in the updated list.
   - The Multisig NFT remains at the script address.

### Helper Functions

1. **`signed_within_threshold:`** Determines if the transaction has been signed by enough authorized signers to meet the threshold.

2. **`multisig_token_name:`** Creates a unique multisig NFT using the transaction Output Reference.

## Getting Started

### Prerequisites

Before you can deploy and test this multi-signature contract, ensure that you
have the Aiken compiler installed to write and compile your contract. Follow the
[Aiken installation instructions](https://aiken-lang.org/installation-instructions)
to get started.

### Building and developing

To build the project, Here are the steps to compile and run the included tests:

1. Clone the repo and navigate inside:

```bash
git clone https://github.com/Anastasia-Labs/aiken-upgradable-multisig
cd aiken-upgradable-multisig
```

2. Run the build command, which both compiles all the functions/examples and
   also runs the included unit tests:

```sh
aiken build
```

## Testing

Comprehensive test cases are provided to ensure the contract behaves as expected under various scenarios with the focus on:

1. **`succeed_init_multisig_fuzzy:`** Tests the successful initialization of the multisig contract and minting of the Multisig NFT.

2. **`succeed_sign_unlock_multisig_fuzzy`**: Tests a successful transaction signing scenario where the number of signatures meets the threshold and funds are unlocked.
3. **`succeed_sign_lock_multisig_fuzzy`**: Tests a successful transaction signing scenario where the number of signatures meets the threshold and funds are locked.
4. **`succeed_update_multisig_fuzzy`**: Tests the:
   - successful adjustment of the signature threshold.

   - successful addition of a new signer to the contract.
   - successful removal of a signer from the contract.
5. **`success_end_multisig:`** Tests the successful termination of the multisig contract and burning of the Multisig NFT.


### Running Tests

To demonstrate and validate these following functionalities,

- Secure Spending of Assets
- Seamless Adjustment of Signer Thresholds
- Dynamic Addition or Removal of Signers

We have prepared comprehensive test cases. For detailed evidence and to view the
test cases associated with these criteria, please refer to the
[Test Documentation](/TEST-README)

To run all tests, simply do:

```sh
aiken check
```

![aiken-upgradable-multisig.gif](/assets/images/aiken_check.gif)

Test results:

![test_report.png](/docs/images/all-multisig.png)

Each test case is designed to validate specific aspects of the multi-signature
contract,To run only specific tests, do:

```sh
aiken check -m `test_case_function_name`
```
