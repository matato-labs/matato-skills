const normalizeTelegramText = (text: string): string => {
  return text.replaceAll("\\n", "\n");
};

export { normalizeTelegramText };
