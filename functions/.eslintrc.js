module.exports = {
  root: true,
  env: {
    es6: true,
    node: true,
  },
  extends: [
    "eslint:recommended",
    "plugin:import/errors",
    "plugin:import/warnings",
    "plugin:import/typescript",
    "google",
    "plugin:@typescript-eslint/recommended",
  ],
  parser: "@typescript-eslint/parser",
  parserOptions: {
    project: ["tsconfig.json", "tsconfig.dev.json"],
    sourceType: "module",
  },
  ignorePatterns: [
    "/lib/**/*", // Ignore built files.
    "/generated/**/*", // Ignore generated files.
  ],
  plugins: [
    "@typescript-eslint",
    "import",
  ],
  rules: {
    // UPDATED: Increase line length from 80 to 120
    "max-len": ["error",{ "code": 120 }],    
    // UPDATED: Allow multiple spaces (or disable entirely)
    "no-multi-spaces": "off",
    // UPDATED: Make trailing spaces a warning instead of error
    "no-trailing-spaces": "warn",
    // Other existing rules...
    "import/no-unresolved": 0,
    "indent": ["error", 2],
  },
};
