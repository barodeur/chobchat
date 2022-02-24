open ReactNative

let str = {
  let manifest = ExpoConstants.constants.manifest
  `${manifest.name} v${manifest.version}${manifest.extra.commitSha->Belt.Option.mapWithDefault(
      "",
      sha => ` - ${sha}`,
    )}`
}

@react.component
let make = (~color="rgba(0, 0, 0, 0.2)") =>
  <TextX style={Style.textStyle(~color, ())}> {str->React.string} </TextX>
