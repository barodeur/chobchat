const { withExpoWebpack } = require('@expo/electron-adapter');

module.exports = config => {
  const expoConfig = withExpoWebpack(config);

  expoConfig.module.rules.
    filter(rule => rule?.use?.loader === 'url-loader').
    forEach(rule => {
      rule.use.options.esModule = false;
    });

  return expoConfig
};
