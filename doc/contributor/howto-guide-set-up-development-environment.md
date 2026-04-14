# Howto-Guide: Set Up Development Environment

This guide is intended for contributors to the `google-cloud-swift` SDK. It will
walk you through the steps necessary to set up your development workstation to
compile the code, run the unit tests, and formatting miscellaneous files.

## Installing Swift

We recommend that you follow the [Getting Started][getting-started-swift] guide.
Once you have `swiftly` and `swift` installed the rest is relatively easy.

You will need Swift >= 6.2. Check the version you have installed with:

```shell
swift --version
```

If you need to upgrade, consider:

```shell
swiftly update
```

## Installing Rust

The auth library uses a Rust core. You will need to compile this code. We
recommend that you follow the [Getting Started][getting-started-rust] guide.
Once you have `cargo` and `rustup` installed the rest is relatively easy.

You will need rust >= 1.94 (released around 2026-03-26). Check the version you
have installed with:

```shell
rustc --version
```

If you need to upgrade, consider:

```shell
rustup update
```

## Installing Go

The code generator is implemented in [Go](https://go.dev). Follow the
[Download and install][golang-install] guide to install Golang.

## IDE Recommendations

Whatever works for you. Several team members use Visual Studio Code, but Swift
can be used with many IDEs.

## Compile the Rust core for auth

```bash
cargo build --release
```

## Compile the Code

```bash
swift build
```

## Run the unit tests

```bash
swift test
```

## Run the unit tests for a specific package

```bash
swift test --package-path packages/gax
```

## Exhaustive builds and tests

Our repository will become too large to build all the packages. The previous
commands only build the default set of packages.

If you make a large change, for example, use a new version of the generator,
consider testing all the packages.

```bash
ci/test.sh
```

## Running lints and unit tests

```bash
ci/lint.sh
git status # Shows any diffs created by `swift-format`
```

If you are seeing errors when running locally that are not present in the CI,
you may need to update your local Swift version.

## Getting code coverage locally

### Install coverage tools (once)

```bash
# TODO
```

### Getting coverage in cobertura format

```bash
# TODO
```

## Integration tests

This guide assumes you are familiar with the [Google Cloud CLI], you have access
to an existing Google Cloud Project, and have enough permissions on that
project.

### One time set up

We use [Secret Manager], [Workflows], and [KMS] to run integration tests. Follow
the [Enable the Secret Manager API] guide to,
as it says, enable the API and make sure that billing is enabled in your
projects. To enable the APIs you can run this command:

```bash
gcloud services enable workflows.googleapis.com firestore.googleapis.com speech.googleapis.com cloudkms.googleapis.com 
gcloud services enable publicca.googleapis.com
```

Verify this is working with something like:

```bash
gcloud firestore databases list
gcloud secrets list
gcloud workflows list
```

It is fine if the list is empty, you just don't want an error.

### Create a service account

The integration tests need a service account (SA) in your project. This service
account is used to:

- Run tests that perform IAM operations, temporarily granting this service
  account some permissions.
- Configure the service account used for test workflows.

For a test project, just create the SA using the CLI:

```bash
gcloud iam service-accounts create swift-sdk-test \
    --display-name="Used in SA testing" \
    --description="This SA gets assigned to roles on short-lived resources during integration tests"
```

For extra safety, disable the service account:

```bash
GOOGLE_CLOUD_PROJECT="$(gcloud config get project)"
gcloud iam service-accounts disable swift-sdk-test@${GOOGLE_CLOUD_PROJECT}.iam.gserviceaccount.com
```

### Running tests

```bash
env GOOGLE_CLOUD_PROJECT="$(gcloud config get project)" swift test --traits IntegrationTests
```

## Miscellaneous Tools

We use a number of tools to format non-Swift code. The CI builds enforce
formatting, you can fix any formatting problems manually (using the CI logs), or
may prefer to install these tools locally to fix formatting problems.

Typically we do not format these files for generated code, so local runs
requires skipping the generated files.

### Format TOML files

We use `taplo` to format the hand-crafted TOML files. Install with:

```bash
cargo install taplo-cli
```

use with:

```bash
git ls-files -z -- \
    '*.toml' ':!:**/testdata/**' ':!:**/generated/**' | \
    xargs -0 taplo fmt
```

### Detect typos in comments and code

We use `typos` to detect typos. Install with:

```bash
cargo install typos-cli
```

### Format Markdown files

We use `mdformat` to format hand-crafted markdown files. Install with:

```bash
python -m venv .venv
source .venv/bin/activate # Or whatever is the right command for your shell
pip install -r ci/requirements.txt
```

use with:

```bash
git ls-files -z -- \
    '*.md' ':!:**/testdata/**' ':!:**/generated/**' | \
    xargs -0 mdformat
```

### Format YAML files

We use `yamlfmt` to format hand-crafted YAML files (mostly GitHub Actions).
Install and use with:

```bash
go install github.com/google/yamlfmt/cmd/yamlfmt@v0.13.0
```

use with:

```bash
git ls-files -z -- \
    '*.yaml' '*.yml' ':!:**/testdata/**' ':!:**/generated/**' | \
    xargs -0 yamlfmt
```

### Format Terraform files

We use `terraform` to format `.tf` files. You will rarely have any need to edit
these files. If you do, you probably know how to [install terraform].

Format the files using:

```bash
git ls-files -z --
    '*.tf' ':!:**/testdata/**' ':!:**/generated/**' | \
    xargs -0 terraform fmt
```

[enable the secret manager api]: https://cloud.google.com/secret-manager/docs/configuring-secret-manager
[getting-started-rust]: https://www.rust-lang.org/learn/get-started
[getting-started-swift]: https://www.swift.org/install/
[golang-install]: https://go.dev/doc/install
[google cloud cli]: https://cloud.google.com/cli
[install terraform]: https://developer.hashicorp.com/terraform/install
[kms]: https://cloud.google.com/kms/
[secret manager]: https://cloud.google.com/secret-manager/
[workflows]: https://cloud.google.com/workflows/
