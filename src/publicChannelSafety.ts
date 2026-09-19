const credentialPatterns = [
  /-----BEGIN(?: [A-Z0-9]+)* PRIVATE KEY(?: [A-Z0-9]+)*-----/i,
  /\b(?:gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,}|glpat-[A-Za-z0-9_-]{20,})\b/,
  /\bsk-(?:proj-)?[A-Za-z0-9_-]{20,}\b/,
  /\bxox[baprs]-[A-Za-z0-9-]{10,}\b/,
  /\b(?:AKIA|ASIA)[0-9A-Z]{16}\b/,
  /\b\d{6,12}:[A-Za-z0-9_-]{30,}\b/,
  /\beyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\b/,
  /\b(?:cookie|set-cookie)\s*:\s*[^;\r\n]*\b(?:session|token|auth|key)=[^;\s\r\n]+/i,
];

const secretAssignmentPattern =
  /\b(?:export\s+)?(?:[A-Za-z_][A-Za-z0-9_]*?)?(?:token|secret|password|api_?key|private_?key|cookie|session(?:_?id)?|credential)[A-Za-z0-9_]*\s*=\s*(?:"[^"\r\n]+"|'[^'\r\n]+'|[^\s\r\n]+)/i;

export const containsSensitivePublicChannelContent = (text: string): boolean =>
  credentialPatterns.some((pattern) => pattern.test(text)) ||
  secretAssignmentPattern.test(text);

export const publicChannelSafetyError =
  "Refusing to send sensitive data over a public channel. Remove credentials or secrets and send a safe summary instead.";
