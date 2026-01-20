module.exports = {
  env: {
    es6: true,
    node: true,
  },
  parserOptions: {
    "ecmaVersion": 2018,
  },
  {
    "root": true,
    "env": { "node": true, "es2020": true },
    "extends": ["eslint:recommended", "google"],
    "parserOptions": { "ecmaVersion": 2020 },
    "rules": {
      "quotes": ["error", "double"],
      "max-len": "off",
      "indent": "off"
    }
  }
  extends: [
    "eslint:recommended",
    "google",
  ],
  rules: {
    "no-restricted-globals": ["error", "name", "length"],
    "prefer-arrow-callback": "error",
    "quotes": ["error", "double", {"allowTemplateLiterals": true}],
  },
  overrides: [
    {
      files: ["**/*.spec.*"],
      env: {
        mocha: true,
      },
      rules: {},
    },
  ],
  globals: {},
};
