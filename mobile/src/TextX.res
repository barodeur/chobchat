open ReactNative

@get external getFontFabily: Style.t => Js.Undefined.t<string> = "fontFamily"

let fontMap = Js.Dict.fromArray([
  ("Sniglet", "https://fonts.gstatic.com/s/sniglet/v12/cIf9MaFLtkE3UjaJxCk.ttf"),
])

let font = Recoil.asyncSelectorFamily({
  key: "Font",
  get: fontFamily => Fn(
    _ =>
      fontFamily->Option.mapWithDefault(Promise.resolve(), name =>
        fontMap
        ->Js.Dict.get(name)
        ->Option.mapWithDefault(Promise.resolve(), Fonts.loadAsync(name, _))
      ),
  ),
})

@react.component
let make = (~style as styleProp=?, ~accessibilityRole=?, ~href=?, ~children) => {
  open Style
  let style =
    [Some(textStyle(~fontFamily="Sniglet", ())), styleProp]
    ->Belt.Array.keepMap(s => s)
    ->StyleSheet.flatten

  Recoil.useRecoilValue(font(style->getFontFabily->Js.Undefined.toOption))
  <Text style ?accessibilityRole ?href> ...children </Text>
}
