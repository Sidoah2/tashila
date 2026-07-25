declare module "stylis" {
  // Accept any signature; consumed by Emotion's StylisPlugin type.
  export const prefixer: (...args: unknown[]) => unknown;
  const _default: unknown;
  export default _default;
}

declare module "stylis-plugin-rtl" {
  const rtlPlugin: (...args: unknown[]) => unknown;
  export default rtlPlugin;
}
