open ReactNative

let manifest = ExpoConstants.constants.manifest
let repository = manifest.extra.repository

let sha = manifest.extra.commitSha
let shortSha = sha->Belt.Option.map(hash => hash->Js.String2.slice(~from=0, ~to_=7))

let url = `${repository.url->Js.String2.replaceByRe(
    %re("/^github\:/"),
    "https://github.com/",
  )}${sha->Option.mapWithDefault("", hash => `/tree/${hash}`)}`

let str = {
  `${manifest.name} v${manifest.version}${shortSha->Belt.Option.mapWithDefault("", hash =>
      ` - ${hash}`
    )}`
}

@react.component
let make = (~color="rgba(0, 0, 0, 0.2)") =>
  <Link href=url textStyle={Style.textStyle(~color, ())}> {str->React.string} </Link>
