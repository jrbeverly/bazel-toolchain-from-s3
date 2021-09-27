# bazel-toolchain-from-s3

Experimenting with setting up Bazek toolchains, when the tools are mirrored into an AWS S3 bucket.

This builds off previous work done in jrbeverly/bazel-external-toolchain-rule for creating toolchains from files.

## Notes

- Implementation of `s3_archive` uses that same model as `http_archive`
- The `repository_rule` does not use `toolchains` like rules, meaning bootstrap rules must be downloaded by `repository_ctx`
- Repository rules can convert labels to paths using the `repository_ctx.path` method

To get a fully managed system that doesn't require tools to be installed on the local system, would likely require a bootstrap rule using a tool that is publicly available. This way it could be downloaded using the `download_and_extract` rule of Bazel, then combined with the other rules for perform the act of downloading binaries. The process as follows:

1. Download & configure the `cloudio` tool for downloading binaries from a cloud source (AWS S3/Azure RM/GCP/etc)
2. Make this tool available to the other repository rules (aspect? label? ?)
3. Repository rule uses this binary to run the download commands

This may have an additional benefit in that the `cloudio` tool could behave in a content-addressable manner, removing the need for URLs (primary/mirrors/etc) for tools. Instead leaving it up to the `cloudio` to download the toolchain from the appropriately known registries.

## Design Jots

- Using something like an `awsrc` file (aim to be similar to `netrc`) to determine which AWS Profile authentication to use for buckets (is this worthwhile? - Maybe - Our default `AWS_PROFILE` may not always have artifact access - think isolated AWS accounts like 'malware')
- Requires a sha256sum checker, which is only really available on linux (MacOS can install, but default is `shasum `), and Windows is PowerShell.
- AWS CLI is working on parts of the environment like `AWS_PROFILE` (which may run tools through `credential_process`)
