// @generated: @expo/next-adapter@3.1.6
// Learn more: https://github.com/expo/expo/blob/master/docs/pages/versions/unversioned/guides/using-nextjs.md#shared-steps

module.exports = {
  plugins: [
    ["@babel/plugin-proposal-private-property-in-object", { "loose": true }],
    ["@babel/plugin-proposal-private-methods", { "loose": true }]
  ],
  presets: ['@expo/next-adapter/babel', "jotai/babel/preset"]
};
