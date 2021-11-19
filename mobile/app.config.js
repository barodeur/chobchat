import _ from "lodash";
import fs from "fs";
import path from "path";
import dotenv from "dotenv";

let config;
if (process.env.APP_ENV === "production") {
  config = Object.entries(process.env)
    .filter(([key, _]) => key.startsWith("PRODUCTION__"))
    .map(([key, value]) => [_.camelCase(key.replace("PRODUCTION__", "")), value])
    .reduce((acc, [key, value]) => ({ ...acc, [key]: value }), {});
} else if (process.env.APP_ENV === "staging") {
  config = Object.entries(process.env)
    .filter(([key, _]) => key.startsWith("STAGING__"))
    .map(([key, value]) => [_.camelCase(key.replace("STAGING__", "")), value])
    .reduce((acc, [key, value]) => ({ ...acc, [key]: value }), {});
} else {
  const envFilePath = path.resolve(process.cwd(), ".env.local");
  if (fs.existsSync(envFilePath)) {
    const dotenvConfig = dotenv.parse(fs.readFileSync(envFilePath));
    config = Object.entries(dotenvConfig)
      .map(([key, value]) => [_.camelCase(key), value])
      .reduce((acc, [key, value]) => ({ ...acc, [key]: value }), {});
  } else {
    config = Object.entries(process.env)
      .map(([key, value]) => [_.camelCase(key), value])
      .reduce((acc, [key, value]) => ({ ...acc, [key]: value }), {});
  }
}

export { config };

export default {
  name: "ChobChat",
  slug: "chobchat",
  scheme: "chobchat",
  version: "1.0.0",
  orientation: "portrait",
  icon: "./assets/icon.png",
  splash: {
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
    bundleIdentifier: "fr.chobert.chobchat",
    buildNumber: "3"
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
    ...config
  }
}
