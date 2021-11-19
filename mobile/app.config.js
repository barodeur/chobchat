import 'dotenv/config';

export default {
  name: "ChobChat",
  slug: "chobchat",
  scheme: "chobchat",
  version: "1.0.0",
  orientation: "portrait",
  icon: "./assets/icon.png",
  splash: {
    image: "./assets/splash.png",
    resizeMode: "contain",
    backgroundColor: "#46cc8d"
  },
  updates: {
    fallbackToCacheTimeout: 0
  },
  assetBundlePatterns: [
    "**/*"
  ],
  ios: {
    supportsTablet: true,
    bundleIdentifier: "fr.chobert.chobchat"
  },
  android: {
    adaptiveIcon: {
      foregroundImage: "./assets/adaptive-icon.png",
      backgroundColor: "#FFFFFF"
    },
    package: "fr.chobert.chobchat"
  },
  web: {
    favicon: "./assets/favicon.png"
  },
  extra: {
    homeserverUrl: process.env.NEXT_PUBLIC_HOMESERVER_URL,
    roomId: process.env.NEXT_PUBLIC_ROOM_ID,
  }
}
