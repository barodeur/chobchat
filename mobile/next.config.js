const { withExpo } = require("@expo/next-adapter");
const withPlugins = require("next-compose-plugins");
const withFonts = require("next-fonts");
const withImages = require("next-images");

const withTM = require("next-transpile-modules")(["react-native-web", "rescript-react-native"]);

module.exports = withExpo(
  withTM(
    withFonts(
      withImages(
        withFonts({
          projectRoom: __dirname,
          images: {
            disableStaticImages: true
          }
        })
      )
    )
  )
)
