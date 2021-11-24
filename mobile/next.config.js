const { withExpo } = require("@expo/next-adapter");
const withPlugins = require("next-compose-plugins");
const withFonts = require("next-fonts");
const withImages = require("next-images");

const withTM = require("next-transpile-modules")(["react-native-web", "rescript-react-native"]);

const config = withPlugins(
  [
    [withTM],
    [withExpo],
    [withFonts],
    [withImages],
  ],
  {
    projectRoot: __dirname,
    images: {
      disableStaticImages: true
    },
  }
)

module.exports = config;
