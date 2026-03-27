{ lib
, buildGoModule
, fetchFromGitHub
}:

buildGoModule rec {
  pname = "aix";
  version = "0.8.0";

  src = fetchFromGitHub {
    owner = "thoreinstein";
    repo = "aix";
    rev = "v${version}";
    hash = "sha256-kfIN8ymsmqQldIMQvlmm39I4++9s+w/2kejY8LbYj6U=";
  };

  vendorHash = "sha256-LWRF8ld/yqxwaCQ0aV0GDeGfUgQ5j75+FK1K2oGLTho=";

  # Integration tests require git in PATH, which isn't available in the nix sandbox
  doCheck = false;

  meta = {
    description = "Package manager for AI assistant configurations — syncs skills and MCP servers across Claude Code, Qwen Code, and Gemini CLI";
    homepage = "https://github.com/thoreinstein/aix";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "aix";
  };
}
