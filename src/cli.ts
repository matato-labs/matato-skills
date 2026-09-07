export const readFlagValue = (args: string[], name: string): string => {
  const inlinePrefix = `--${name}=`;
  const inlineValue = args.find((arg) => arg.startsWith(inlinePrefix));
  if (inlineValue) return inlineValue.slice(inlinePrefix.length);

  const flagIndex = args.indexOf(`--${name}`);
  return flagIndex === -1 ? "" : (args[flagIndex + 1] ?? "");
};
