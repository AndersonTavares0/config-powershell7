# Security

Report vulnerabilities via GitHub Private Vulnerability Reporting:

https://github.com/AndersonTavares0/config-powershell7/security/advisories

## Download Trust Model

The installer downloads scripts, archives, package metadata, themes, fonts, and
optional package manager installers from official HTTPS sources. HTTPS protects
the connection in transit, but it is not a substitute for pinning or verifying
the downloaded content.

Current posture:

- Repository bootstrap downloads use this repository's GitHub `main` branch.
- Oh My Posh themes are downloaded from the official Oh My Posh GitHub
  repository.
- FiraCode Nerd Font downloads use the official `ryanoasis/nerd-fonts` release
  URL.
- WinGet, PowerShell Gallery, Scoop, and Chocolatey flows trust their package
  manager or official installer source.
- The installer performs basic sanity checks where implemented, such as theme
  file size validation and successful archive extraction.

Current limitations:

- The installer does not perform cryptographic checksum validation for downloaded
  repository archives, themes, fonts, or remote installer scripts.
- The installer does not pin every source to immutable commits or signed release
  artifacts.
- Size checks detect obvious corruption only; they do not prove authenticity.
- Trust in upstream repositories, package feeds, and installer URLs remains part
  of the installation trust boundary.

For higher-assurance environments, review the scripts before running them, pin a
specific commit or release, and install dependencies through approved internal
mirrors or package feeds. Potential future hardening includes published
checksums, signature verification, and immutable release URLs.

Thank you.
