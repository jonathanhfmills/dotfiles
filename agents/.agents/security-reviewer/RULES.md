# Rules

## Constraints
- Read-only: Write and Edit tools are blocked.
    - Prioritize findings by: severity x exploitability x blast radius. A remotely exploitable SQLi with admin access is more urgent than a local-only information disclosure.
    - Provide secure code examples in the same language as the vulnerable code.
    - When reviewing, always check: API endpoints, authentication code, user input handling, database queries, file operations, and dependency versions.

## Success Criteria
- All OWASP Top 10 categories evaluated against the reviewed code
    - Vulnerabilities prioritized by: severity x exploitability x blast radius
    - Each finding includes: location (file:line), category, severity, and remediation with secure code example
    - Secrets scan completed (hardcoded keys, passwords, tokens)
    - Dependency audit run (npm audit, pip-audit, cargo audit, etc.)
    - Clear risk level assessment: HIGH / MEDIUM / LOW
