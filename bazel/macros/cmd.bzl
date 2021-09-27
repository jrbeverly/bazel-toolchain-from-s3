def sha256sum(repository_ctx):
    """Resolves the sha256sum path.

    Args:
      repository_ctx: The repository context
    Returns:
      The path to the docker tool
    """
    if repository_ctx.which("sha256sum"):
        return str(repository_ctx.which("sha256sum"))

    fail("Path to the sha256sum tool could not be resolved automatically. Try installing coreutils.")

def sha256sum_root(repository_ctx, tool_path, filepath):
    """Calculates the SHA256 sum of the given file.

    Args:
      repository_ctx: The repository context
      tool_path: The path to the AWS CLI tool
      filepath: The path to the local file
    Returns: 
      The SHA256 sum of the file.
    """
    repository_ctx.report_progress("Calculating checksum {}".format(filepath))
    result = repository_ctx.execute([tool_path, filepath])
    if result.return_code != 0:
        fail("Failed to calculate checksum: {}".format(result.stderr))
    return result.stdout.split(" ")[0]


def aws(repository_ctx):
    """Resolves the awscli path.

    Args:
      repository_ctx: The repository context
    Returns:
      The path to the docker tool
    """
    if repository_ctx.which("aws"):
        return str(repository_ctx.which("aws"))

    fail("Path to the aws tool was not provided and it could not be resolved automatically.")

def _aws_profile(awsrc = {}):
    """Downloads the archive from AWS S3 using the AWS CLI.

    Args:
      awsrc: Configuration options for the AWS CLI tool
    """
    extra_flags = ["--profile", awsrc["profile"]] if "profile" in awsrc else []
    extra_environment = {"AWS_CONFIG_FILE": awsrc["profile_location"]} if "profile_location" in awsrc else {}
    return (extra_flags, extra_environment)

def awsrc_default_path(ctx):
    return ctx.os.environ.get("BAZEL_AWSRC", "")

def read_awsrc(ctx, filename):
    """Utility function to parse the basic .bazel-awsrc file.

    Args:
      ctx: The repository context of the repository rule calling this utility
        function.
      filename: the name of the .netrc file to read
    Returns:
      dict mapping a machine names to a dict with the information provided
      about them
    """
    contents = ctx.read(filename)
    awsrc = {}
    for line in contents.splitlines():
        if line.startswith("#"):
            continue

        if line == "":
            continue

        tokens = [
            w.strip()
            for w in line.split("=")
            if len(w.strip()) > 0
        ]
        if len(tokens) > 2:
            if line.contains("#"):
                fail("{} does not support trailing comments. Line was [{}] but wanted key=value".format(filename, line))
            fail("{} does not match the expected format. Line was [{}] but wanted key=value".format(filename, line))

        awsrc[tokens[0]] = tokens[1]

    return awsrc

def aws_s3_cp(repository_ctx, tool_path, s3_uri, local_path, awsrc = {}):
    """Downloads the archive from AWS S3 using the AWS CLI.

    Args:
      repository_ctx: The repository context
      tool_path: The path to the AWS CLI tool
      s3_uri: The S3 object URI
      local_path: The path to the local file to write
      awsrc: Additional configuration options for the AWS CLI tool
    """
    extra_flags, extra_environment = _aws_profile(awsrc)
    cmd = [tool_path] + extra_flags + ["s3", "cp", s3_uri, local_path]

    repository_ctx.report_progress("Downloading {}.".format(s3_uri))
    result = repository_ctx.execute(cmd, timeout = 1800, environment = extra_environment)
    if result.return_code != 0:
        fail("Failed to download {}: {}".format(s3_uri, result.stderr))

