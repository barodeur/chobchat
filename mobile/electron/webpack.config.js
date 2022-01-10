const path = require("path")
const { withExpoWebpack } = require('@expo/electron-adapter');

module.exports = config => {
  const expoConfig = withExpoWebpack(config);

  expoConfig.module.rules.
    filter(rule => rule?.use?.loader === 'url-loader').
    forEach(rule => {
      rule.use.options.esModule = false;
    });

  expoConfig.resolve.alias.react = path.resolve('./node_modules/react')

  return expoConfig
};
