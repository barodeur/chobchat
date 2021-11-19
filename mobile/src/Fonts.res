type fontMap = Js.Dict.t<string>

@module("expo-font") external useFonts: fontMap => (bool, Js.Exn.t) = "useFonts"
@module("expo-font") external loadAsync: (string, string) => Promise.t<unit> = "loadAsync"
