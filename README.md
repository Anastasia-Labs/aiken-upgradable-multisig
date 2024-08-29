Wesh 🍄 wesh09 Online flake.nix Suganya — 08/26/2024 6:05 PM the one you are
working on is plug and play 2.0 proposal right? Plug and play version 1 is
already done by Nikhil and what you are doing now is like enhancing the existing
system? Suganya — 08/26/2024 6:23 PM
https://github.com/Anastasia-Labs/aiken-upgradable-multisig/blob/main/validators/multisig.ak
Am I in the correct link? I don't see anything here Wesh 🍄 — 08/26/2024 6:23 PM
That's the main branch right? Check the endpoints branch Suganya — 08/26/2024
6:24 PM ahh got it, Wesh 🍄 — 08/26/2024 7:14 PM Hi Suganya. Perhaps, you can
start by writing the README.md file for the multi-sig for the main github page
with links to the design specs and tests. I'm just thinking on the go. The
Payment-Subscription Contract also needs a bit of documentation for the main
page and links to the design specs and test documentation (Yet to be
implemented). That way I can focus on making the code changes Mark suggests if
that's okay with you. Suganya — 08/26/2024 7:23 PM yes we can coordinate this
way.. Am ok the deadline for the milestone submission is we or thursday this
week right? Wesh 🍄 — 08/26/2024 7:24 PM Set for 28th. The day after tomorrow.
Suganya — 08/26/2024 7:47 PM Evidence of Milestone Completion for Upgradable
Multisignature Smart Contract:

Secure Spending of Assets: Documentation showcasing successful asset
transactions executed by authorized members, along with evidence of rejected
unauthorized transactions => WIP

Seamless Adjustment of Signer Thresholds: Documentation with screenshots
illustrating the process of adjusting signer thresholds within the smart
contract, accompanied by user feedback on the experience => WIP

Dynamic Addition or Removal of Signers: Documentation outlining the procedure
for dynamically adding or removing signers from the multisignature contract =>
WIP

All 3 documentations are work in progress right? I will work on the readme file
of the multiig but do you think we need for the milestone 1 completion? Wesh 🍄
— 08/26/2024 7:48 PM They are in the README.md Suganya — 08/26/2024 7:50 PM here
? https://github.com/Anastasia-Labs/aiken-upgradable-multisig/tree/endpoints
Wesh 🍄 — 08/26/2024 9:30 PM Still meeting? Suganya — 08/26/2024 9:30 PM yes, I
sent the meeting invite Wesh 🍄 — 08/26/2024 9:43 PM
https://github.com/Anastasia-Labs/bridge-template GitHub GitHub -
Anastasia-Labs/bridge-template: This template enables the ... This template
enables the bridging or wrapping of tokens from other chains onto the Cardano
network, allowing for seamless interoperability. -
Anastasia-Labs/bridge-template GitHub - Anastasia-Labs/bridge-template: This
template enables the ... Suganya — 08/26/2024 9:57 PM I forgot one thing I
installed aiken using aikup Image any idea? Wesh 🍄 — 08/26/2024 10:16 PM Not
sure how to solve that at the momment but it looks like aiken is not installed
yet. Try using this flake.nix at the root level of your repository { description
= "A flake for typst";

nixConfig.bash-prompt = "\\[\\e[0m\\][\\[\\e[0;2m\\]nix-develop
\\[\\e[0;1m\\]Template \\[\\e[0;32m\\]\\w\\[\\e[0m\\]]\\[\\e[0m\\]$
\\[\\e[0m\\]";

inputs = { Expand flake.nix 1 KB Allows running typst and aiken. Then run nix
develop and You should be good. Suganya — 08/27/2024 6:02 AM Hi Harun, Good day!
Prepared a initial MD for multi-sig contract

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

Each test case is designed to validate specific aspects of the multi-signature
contract,To run only specific tests, do:

```sh
aiken check -m `test_case_function_name`
```
