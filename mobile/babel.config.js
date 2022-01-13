// @generated: @expo/next-adapter@3.1.6
// Learn more: https://github.com/expo/expo/blob/master/docs/pages/versions/unversioned/guides/using-nextjs.md#shared-steps

module.exports = {
  plugins: [
    ["@babel/plugin-proposal-private-property-in-object", { "loose": true }],
    // The following line should be uncomented to silence some nextjs warnings,
    // but when uncommented, it causes FlatList to raise an error,
    // see https://stackoverflow.com/questions/69922302
    // ["@babel/plugin-proposal-private-methods", { "loose": true }]
  ],
  presets: ["@expo/next-adapter/babel", "jotai/babel/preset"]
};
