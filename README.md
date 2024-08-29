# Upgradable Multi-Signature Contract

## Overview

This multi-signature contract is designed for secure transactions on blockchain
platforms, requiring multiple signatures to authorize a transaction. It enables
you to:

- Set up a multi-signature wallet with a list of authorized signatories.
- Define a threshold for the number of signatures required to approve
  transactions.
- Update the list of signatories and threshold as needed.
- Enforce spending limits for transactions.

## Design Documentation

For a comprehensive understanding of the contract's architecture, design
decisions, and implementation details, please refer to the
[Design Documentation](https://github.com/Anastasia-Labs/aiken-upgradable-multisig/blob/endpoints/docs/design-specs/upgradable-multi-sig.pdf).
This documentation provides in-depth insights into the contract's design,
including its components, and detailed explanations of its functionality.

## Contract Functionality

### Validator Function

The `multisig_validator` function is responsible for:

1. **Validation of Signatures**: Checks if the number of valid signers meets or
   exceeds the threshold required for the transaction.
2. **Spending Limit Enforcement**: Ensures that the transaction adheres to the
   spending limit specified in the contract.
3. **Datum Validation**: Validates that the contract's datum is correctly
   updated, if applicable.

### Helper Functions

1. **`get_asset_amount`**: Retrieves the amount of a specific asset from a
   `Value`.

2. **`validate_sign`**: This function ensures that a transaction with a `Sign`
   redeemer is valid under the following conditions:

   - The amount being transferred from the input to the output does not exceed
     the spending limit defined in the contract.

   - The datum associated with the output UTxO is consistent with the
     expectations and rules defined in the contract.

- **`datum_is_valid`**: Ensures that the datum has not been altered
  inappropriately.

- **`validate_update`**: Validates updates to the contract, including changes to
  the list of signatories and the threshold.

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

Several test cases are provided to ensure the contract behaves as expected:

1. **`success_sign`**: Tests a successful transaction signing scenario where the
   number of signatures meets the threshold.
2. **`reject_insufficient_signatures`**: Tests the rejection of a transaction
   when insufficient signatures are provided.
3. **`success_adjust_threshold`**: Tests the successful adjustment of the
   signature threshold.
4. **`success_add_signer`**: Tests the successful addition of a new signer to
   the contract.
5. **`success_remove_signer`**: Tests the successful removal of a signer from
   the contract.

### Running Tests

To demonstrate and validate these following functionalities,

- Secure Spending of Assets
- Seamless Adjustment of Signer Thresholds
- Dynamic Addition or Removal of Signers

We have prepared comprehensive test cases. For detailed evidence and to view the
test cases associated with these criteria, please refer to the
[Test Documentation](https://github.com/Anastasia-Labs/aiken-upgradable-multisig/blob/endpoints/lib/upgradable-multisig/tests/README.md)

To run all tests, simply do:

```sh
aiken check
```

![aiken-upgradable-multisig.gif](/assets/images/aiken-upgradable-multisig.gif)

Test results:

![test_report.png](/assets/images/test_report.png)

Each test case is designed to validate specific aspects of the multi-signature
contract,To run only specific tests, do:

```sh
aiken check -m `test_case_function_name`
```
