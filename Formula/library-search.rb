class LibrarySearch < Formula
  desc "Local semantic search for your personal book collection"
  homepage "https://github.com/paraped/library-search"
  url "https://github.com/paraped/library-search/archive/refs/tags/v0.3.0.tar.gz"
  sha256 "b94b78ec5048ca53be601e1cd9a05200789ba537143bd2452be0a5b723e7ecf4"
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

    # The venv's python symlink was built against Homebrew's sandbox temp dir
    # which is deleted after install. Rebuild the venv in-place so uv uses its
    # persistent Python cache (~/.local/share/uv/python) instead.
    rm_rf libexec/".venv"
    system Formula["uv"].opt_bin/"uv", "sync", "--project", libexec.to_s,
           "--no-dev", "--frozen", "--python", "3.13"
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
