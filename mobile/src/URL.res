module WHATWG = {
  type url
  type searchParams

  type t = url

  module SearchParams = {
    type t = searchParams

    @send @return(nullable) external get: (t, string) => option<string> = "get"
  }

  @new external make: string => t = "URL"
  @get external searchParams: t => searchParams = "searchParams"
}

type url = WHATWG(WHATWG.url) | ExpoLinking(ExpoLinking.parseResponse)

let make = switch PlatformX.platform {
| Mobile(_) => str => str->ExpoLinking.parse->ExpoLinking
| _ => str => str->WHATWG.make->WHATWG
}

let getSearchParam = (url, key) =>
  switch url {
  | ExpoLinking(parseResponse) => parseResponse.queryParams->Js.Dict.get(key)
  | WHATWG(url) => url->WHATWG.searchParams->WHATWG.SearchParams.get(key)
  }
