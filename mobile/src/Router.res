type router = NextRouter(Next.Router.t) | Other

let useRouter = switch PlatformX.currentAdapter {
| Web =>
  () => {
    let router = Next.Router.useRouter()
    NextRouter(router)
  }
| _ => () => Other
}

let replace = (router, url) =>
  switch router {
  | NextRouter(nextRouter) => nextRouter->Next.Router.replace(url)
  | _ => ()
  }

module Query = {
  let get = (router, codec) =>
    switch router {
    | NextRouter(nextRouter) =>
      nextRouter
      ->Next.Router.getQuery
      ->Jzon.decodeWith(codec)
      ->Belt.Result.mapWithDefault(None, v => Some(v))
    | Other => None
    }
}
