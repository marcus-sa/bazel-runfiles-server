SERVE_ATTRS = {
    "server": attr.label(
        default = "//brs",
        executable = True,
        cfg = "host",
    ),
}

def _serve_impl(ctx):
    return [
        DefaultInfo(
            runfiles = serve_this(ctx, index = ctx.file.index),
        ),
    ]

_serve = rule(
    implementation = _serve_impl,
    doc = "serve data files in an ibazel-aware local development server",
    executable = True,
    attrs = dict(SERVE_ATTRS, **{
        "data": attr.label_list(
            allow_files = True,
        ),
        "index": attr.label(
            allow_single_file = True,
        ),
    }),
)

def serve(name, data = None, index = None):
    """Serve arbitrary data files in an ibazel-aware local development server.

Use this macro when you have a rule whose implementation you do not control that you would like to
run in a local development server."""
    _serve(
        name = name,
        data = data or [],
        index = index,
        tags = [
            "ibazel_live_reload",
            "ibazel_notify_changes",
        ],
    )

def serve_this(ctx, index = None, other_files = None):
    """Helper function allowing rules to boot an ibazel-aware web server on bazel run.

This is neither a rule implementation function nor a macro. It is a helper function designed to be
called from other rule implementations. Rules producing outputs that can be usefully previewed in a
browser can call this function to set up all the serving logic. Requirements:

- The rule must be executable. (This function writes to ctx.outputs.executable.)
- The rule must mix SERVE_ATTRS into its own attributes: `attrs = dict(SERVE_ATTRS, **{...})`.

Returns:
    A runfiles object. The calling rule must propagate this as part of its own runfiles.
    """

    # Write a script to invoke the server at bazel run time.
    ctx.actions.write(
        # The $@ propagates flags passed to this executable (ctx.outputs.executable) to the
        # underlying one (ctx.executable.server). This allows the integration test runner to invoke
        # this executable with a --port flag.
        content = '%s %s "$@"' % (
            ctx.executable.server.short_path,
            ("--index " + index.short_path) if index else "",
        ),
        output = ctx.outputs.executable,
    )

    return ctx.runfiles(
        collect_default = True,
        files = [index] if index else [],
        transitive_files = depset(
            transitive = [ctx.attr.server[DefaultInfo].default_runfiles.files] +
                         ([other_files] if other_files else []),
        ),
    )