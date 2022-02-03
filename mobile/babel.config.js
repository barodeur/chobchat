// @generated: @expo/next-adapter@3.1.6
// Learn more: https://github.com/expo/expo/blob/master/docs/pages/versions/unversioned/guides/using-nextjs.md#shared-steps

module.exports = (api) => {
  api.cache.using(() => process.env.NODE_ENV)

  const isMetro = api.caller(caller => caller && caller.name === "metro");

  const nextPreset = "next/babel";
  const expoPreset = [
    require("babel-preset-expo"),
    {
      web: { useTransformReactJsxExperimental: true },
      // Disable the `no-anonymous-default-export` plugin in babel-preset-expo
      // so users don't see duplicate warnings.
      "no-anonymous-default-export": false,
    },
  ];

  return {
    presets: [
      isMetro ? expoPreset : nextPreset,
      "jotai/babel/preset"
    ]
  }
}
