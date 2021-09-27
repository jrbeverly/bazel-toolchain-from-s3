load("@bazel_tools//tools/build_defs/repo:utils.bzl", "workspace_and_buildfile")
load("//bazel/macros:cmd.bzl", "sha256sum", "sha256sum_root", "aws", "aws_s3_cp", "awsrc_default_path", "read_awsrc")

_HTTP_FILE_BUILD = """
package(default_visibility = ["//visibility:public"])
filegroup(
    name = "file",
    srcs = ["{}"],
)
"""

def _s3_archive_impl(ctx):
    if not ctx.attr.url:
        fail("At least one of url and urls must be provided")
    if ctx.attr.build_file and ctx.attr.build_file_content:
        fail("Only one of build_file and build_file_content can be provided.")

    aws_path = aws(ctx)
    sha256sum_path = sha256sum(ctx)

    downloaded_file_path = ctx.path(ctx.attr.url).basename
    download_path = ctx.path("file/" + downloaded_file_path)

    awsrc_filepath = awsrc_default_path(ctx)
    awsrc = {}
    if awsrc_filepath != "":
        awsrc = read_awsrc(ctx, awsrc_filepath)
    aws_s3_cp(ctx, aws_path, ctx.attr.url, download_path, awsrc)

    ctx.file("WORKSPACE", "workspace(name = \"{name}\")".format(name = ctx.name))
    ctx.file("file/BUILD", _HTTP_FILE_BUILD.format(downloaded_file_path))

    downloaded_sha256 = sha256sum_root(ctx, sha256sum_path, download_path)
    if downloaded_sha256 != ctx.attr.sha256:
        fail("Error downloading [{}] to {}: Checksum was {} but wanted {}".format(
            ctx.attr.url,
            download_path,
            downloaded_sha256,
            ctx.attr.sha256,
        ))

    ctx.extract(download_path, stripPrefix = ctx.attr.strip_prefix)
    workspace_and_buildfile(ctx)

s3_archive = repository_rule(
    implementation = _s3_archive_impl,
    attrs = {
        "profile": attr.string(doc = "Profile to use for authentication."),  # This is... bleh?
        "url": attr.string(
            doc =
                """A URL to a file that will be made available to Bazel.
    This must be a file, http or https URL. Redirections are followed.
    Authentication is not supported.
    This parameter is to simplify the transition from the native http_archive
    rule. More flexibility can be achieved by the urls parameter that allows
    to specify alternative URLs to fetch from.
    """,
        ),
        "sha256": attr.string(
            doc = """The expected SHA-256 of the file downloaded.
    This must match the SHA-256 of the file downloaded. _It is a security risk
    to omit the SHA-256 as remote files can change._ At best omitting this
    field will make your build non-hermetic. It is optional to make development
    easier but either this attribute or `integrity` should be set before shipping.""",
        ),
        "strip_prefix": attr.string(
            doc = """A directory prefix to strip from the extracted files.
    Many archives contain a top-level directory that contains all of the useful
    files in archive. Instead of needing to specify this prefix over and over
    in the `build_file`, this field can be used to strip it from all of the
    extracted files.
    For example, suppose you are using `foo-lib-latest.zip`, which contains the
    directory `foo-lib-1.2.3/` under which there is a `WORKSPACE` file and are
    `src/`, `lib/`, and `test/` directories that contain the actual code you
    wish to build. Specify `strip_prefix = "foo-lib-1.2.3"` to use the
    `foo-lib-1.2.3` directory as your top-level directory.
    Note that if there are files outside of this directory, they will be
    discarded and inaccessible (e.g., a top-level license file). This includes
    files/directories that start with the prefix but are not in the directory
    (e.g., `foo-lib-1.2.3.release-notes`). If the specified prefix does not
    match a directory in the archive, Bazel will return an error.""",
        ),
        "build_file": attr.label(
            allow_single_file = True,
            doc =
                "The file to use as the BUILD file for this repository." +
                "This attribute is an absolute label (use '@//' for the main " +
                "repo). The file does not need to be named BUILD, but can " +
                "be (something like BUILD.new-repo-name may work well for " +
                "distinguishing it from the repository's actual BUILD files. " +
                "Either build_file or build_file_content can be specified, but " +
                "not both.",
        ),
        "build_file_content": attr.string(
            doc =
                "The content for the BUILD file for this repository. " +
                "Either build_file or build_file_content can be specified, but " +
                "not both.",
        ),
        "workspace_file": attr.label(
            doc =
                "The file to use as the `WORKSPACE` file for this repository. " +
                "Either `workspace_file` or `workspace_file_content` can be " +
                "specified, or neither, but not both.",
        ),
        "workspace_file_content": attr.string(
            doc =
                "The content for the WORKSPACE file for this repository. " +
                "Either `workspace_file` or `workspace_file_content` can be " +
                "specified, or neither, but not both.",
        ),
    },
)
