class LibrarySearch < Formula
  desc "Local semantic search for your personal book collection"
  homepage "https://github.com/paraped/library-search"
  url "https://github.com/paraped/library-search/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "PLACEHOLDER_RUN_brew_audit_AFTER_RELEASE"
  license "MIT"

  depends_on "uv"

  def install
    # Pre-install all Python dependencies into a local venv
    system Formula["uv"].opt_bin/"uv", "sync", "--project", buildpath.to_s,
           "--no-dev", "--frozen"

    # Install source + venv to libexec
    libexec.install Dir["*.py", "*.html", "pyproject.toml", "uv.lock", ".venv"]

    # Wrapper script — uses the pre-built venv, no uv needed at runtime
    (bin/"library-search").write <<~SH
      #!/bin/bash
      exec "#{libexec}/.venv/bin/python" "#{libexec}/web_server.py" "$@"
    SH
    chmod 0755, bin/"library-search"
  end

  service do
    run          bin/"library-search"
    keep_alive   true
    log_path     var/"log/library-search.log"
    error_log_path var/"log/library-search.log"
  end

  def post_install
    # Create default books directory
    (Path.home/"Book_Library").mkpath
  end

  def caveats
    <<~EOS
      Drop your PDFs into ~/Book_Library/
      Books are indexed automatically when the server starts.

      Start now:        library-search
      Start on login:   brew services start library-search
      Open UI:          http://localhost:8765

      Config file:      ~/.config/library-search/config.json
      Settings UI:      http://localhost:8765  → Settings tab

      Optional LLM tagging (better topic detection):
        Get an Anthropic API key at https://platform.claude.com
        Enter it in the Settings tab → API key field
        Then click "Tag all books" in the Books tab
    EOS
  end

  test do
    fork { exec bin/"library-search" }
    sleep 3
    assert_match "books", shell_output("curl -sf http://localhost:8765/books")
  end
end
