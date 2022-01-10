module LinkingX = Linking
open ReactNative

type errItem =
  | MissingConfig
  | MatrixError(Matrix.err)
  | DeviceError(Device.err)
  | StorageError(CrossSecureStore.err)

type err = array<errItem>

let createConfigValue = configSelector =>
  Jotai.Atom.makeDerived(getter =>
    getter
    ->Jotai.Atom.get(Config.jotaiAtom)
    ->Option.mapWithDefault(Error([MissingConfig]), config => config->configSelector->Ok)
  )

let homeserverUrl = createConfigValue(c => c.homeserverUrl)
let roomId = createConfigValue(c => c.roomId)

let guestMatrixClient = Jotai.Atom.makeDerived(getter =>
  getter->Jotai.Atom.get(homeserverUrl)->Result.map(Matrix.createClient(_))
)
let flows = Jotai.Atom.makeAsyncDerived(getter =>
  switch getter->Jotai.Atom.get(guestMatrixClient) {
  | Ok(client) => client->Matrix.Login.getFlows->PResult.mapError(err => [MatrixError(err)])
  | Error(_) as errorRes => Promise.resolve(errorRes)
  }
)
let sessionCounterState = Jotai.Atom.make(0)
let loginTokenState = Jotai.Atom.make(None)
let accessTokenFromStorage = Jotai.Atom.makeAsyncDerived(getter => {
  getter->Jotai.Atom.get(sessionCounterState)->ignore
  CrossSecureStore.getItem("accessToken")->PResult.mapError(err => [StorageError(err)])
})
let accessTokenFromLoginToken = Jotai.Atom.makeAsyncDerived(getter =>
  switch (
    getter->Jotai.Atom.get(loginTokenState),
    getter->Jotai.Atom.get(guestMatrixClient),
    getter->Jotai.Atom.get(Device.deviceId),
  ) {
  | (Some(token), Ok(client), Ok(deviceId)) =>
    client
    ->Matrix.Login.loginWithToken({token: token, deviceId: Some(deviceId)})
    ->PResult.map(payload => Some(payload.accessToken))
    ->PResult.mapError(err => [MatrixError(err)])
  | (None, Ok(_), Ok(_)) => Promise.resolve(Ok(None))
  | (_, matrixClientRes, deviceIdRes) =>
    StateUtils.mergeResultErrors2(
      matrixClientRes,
      deviceIdRes->Result.mapError(err => [DeviceError(err)]),
    )->Promise.resolve
  }
)
let accessToken = Jotai.Atom.makeDerived(getter =>
  switch (
    getter->Jotai.Atom.get(accessTokenFromLoginToken),
    getter->Jotai.Atom.get(accessTokenFromStorage),
  ) {
  | (Ok(fromLoginOpt), Ok(fromStorageOpt)) =>
    [fromLoginOpt, fromStorageOpt]->Belt.Array.keepMap(v => v)->Belt.Array.get(0)->Result.ok
  | (fromLoginRes, fromStorageRes) =>
    [fromLoginRes, fromStorageRes]
    ->Belt.Array.map(Result.getErrorWithDefault(_, []))
    ->Belt.Array.concatMany
    ->Result.error
  }
)

let matrixClient = Jotai.Atom.makeDerived(getter =>
  switch (getter->Jotai.Atom.get(accessToken), getter->Jotai.Atom.get(homeserverUrl)) {
  | (Ok(Some(token)), Ok(url)) =>
    Matrix.createClient(url, ~accessToken=token)->Option.some->Result.ok
  | (Ok(None), _) => None->Result.ok
  | (accessTokenRes, homeserverUrlRes) =>
    StateUtils.mergeResultErrors2(accessTokenRes, homeserverUrlRes)
  }
)

let currentUserId = Jotai.Atom.makeAsyncDerived(getter =>
  getter
  ->Jotai.Atom.get(matrixClient)
  ->Belt.Result.map(clientOpt =>
    clientOpt->Belt.Option.mapWithDefault(None->Result.ok->Promise.resolve, client =>
      client
      ->Matrix.Account.whoAmI
      ->PResult.mapError(err => [MatrixError(err)])
      ->PResult.map(payload => Some(payload.userId))
      ->PResult.asyncTap(userIdOpt =>
        userIdOpt
        ->Option.flatMap(_ =>
          Option.map(client.accessToken, accessToken =>
            CrossSecureStore.setItem("accessToken", accessToken)
          )
        )
        ->Option.mapWithDefault(Promise.resolve(), p => p->Promise.thenResolve(_ => ()))
      )
      ->Promise.then(res =>
        switch res {
        | Error(errors)
          if errors
          ->Js.Array2.filter(error =>
            switch error {
            | MatrixError(UnknownToken(_)) => true
            | _ => false
            }
          )
          ->Belt.Array.length > 0 =>
          CrossSecureStore.removeItem("accessToken")->Promise.thenResolve(_ => Ok(None))
        | _ => Promise.resolve(res)
        }
      )
    )
  )
  ->PResult.wrapPromise
)

module IdentityProviderButton = {
  @react.component
  let make = (~name, ~style=?, ~redirectUrl) =>
    <Pressable
      style={({pressed}) =>
        [
          Style.viewStyle(
            ~paddingVertical=6.->Style.dp,
            ~paddingHorizontal=10.->Style.dp,
            ~borderWidth=1.,
            ~borderColor=Color.white,
            ~backgroundColor={Color.rgba(~r=255, ~g=255, ~b=255, ~a=pressed ? 0.2 : 0.)},
            ~borderRadius=5.,
            (),
          )->Option.some,
          style,
        ]->Style.arrayOption}
      onPress={e => {
        e->ReactNative.Event.PressEvent.preventDefault
        switch PlatformX.platform {
        | Web(Electron) => ElectronRendererIPC.sendSync(OpenExternal(redirectUrl))->ignore
        | _ => ExpoLinking.openURL(redirectUrl)
        }

        ()
      }}>
      {_ =>
        <Text
          style={Style.textStyle(~color=Color.white, ~fontSize=16., ())}
          accessibilityRole=#link
          href={redirectUrl}>
          {`Se connecter avec ${name}`->React.string}
        </Text>}
    </Pressable>
}

module Flow = {
  @react.component
  let make = (~matrixClient: Matrix.client, ~flow: Matrix.Login.flow, ~redirectUrl) =>
    switch flow {
    | SSO({identityProviders}) =>
      identityProviders
      ->Js.Array2.map(({id, name}) =>
        <IdentityProviderButton
          style={Style.viewStyle(~alignSelf=#center, ())}
          key=id
          name
          redirectUrl={matrixClient->Matrix.Login.getSsoRedirectUrl(id, ~redirectUrl)}
        />
      )
      ->React.array
    | Other => React.null
    }
}

module Authenticate = {
  let redirectUrl = switch PlatformX.platform {
  | Web(Electron) => "chobchat://"
  | _ => ExpoLinking.createURL(. "/")
  }

  @react.component
  let make = () => {
    let url = LinkingX.useURL()
    let router = Router.useRouter()
    let queryLoginToken =
      url->Option.flatMap(url => url->URL.make->URL.getSearchParam("loginToken"))

    let matrixClient = Jotai.React.useReadable(guestMatrixClient)
    let flows = Jotai.React.useReadable(flows)
    let setLoginTokenState = Jotai.React.useWritable(loginTokenState)

    React.useEffect1(() => {
      setLoginTokenState(_ => queryLoginToken)
      router->Router.replace("/")
      None
    }, [queryLoginToken])

    <ReactNative.SafeAreaView
      style={ReactNative.Style.viewStyle(
        ~flex=1.,
        ~backgroundColor=Colors.green,
        ~justifyContent=#center,
        (),
      )}>
      <ReactNative.Image
        style={ReactNative.Style.imageStyle(
          ~alignSelf=#center,
          ~width=80.->ReactNative.Style.dp,
          ~height=80.->ReactNative.Style.dp,
          ~borderRadius=12.,
          ~marginBottom=20.->ReactNative.Style.dp,
          (),
        )}
        source={ReactNative.Image.Source.fromRequired(
          ReactNative.Packager.require("../assets/icon.png"),
        )}
      />
      {switch (matrixClient, flows) {
      | (Ok(client), Ok(flows)) =>
        flows
        ->Belt.Array.mapWithIndex((idx, flow) =>
          <Flow key={idx->Belt.Int.toString} flow redirectUrl matrixClient=client />
        )
        ->React.array
      | _ => <Text> {"Impossible de charger les flows"->React.string} </Text>
      }}
    </ReactNative.SafeAreaView>
  }
}

@react.component
let make = (~children) => {
  let currentUserId = Jotai.React.useReadable(currentUserId)

  switch currentUserId {
  | Ok(None) => <Authenticate />
  | Ok(Some(_)) => children
  | _ => <Text> {"OOPS"->React.string} </Text>
  }
}
