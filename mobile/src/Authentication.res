module LinkingX = Linking
open ReactNative

type errItem =
  | MissingConfig
  | MatrixError(Matrix.err)
  | DeviceError(Device.err)
  | StorageError(CrossSecureStore.err)

type err = array<errItem>

let createConfigValue = configSelector =>
  Jotai.Atom.makeComputed(({get}) =>
    get(Config.jotaiAtom)->Option.mapWithDefault(Error([MissingConfig]), config =>
      config->configSelector->Ok
    )
  )

let homeserverUrl: Jotai.Atom.t<_, Jotai.Atom.Actions.set<string>, _> = createConfigValue(c =>
  c.homeserverUrl
)
let roomId: Jotai.Atom.t<_, Jotai.Atom.Actions.set<string>, _> = createConfigValue(c => c.roomId)

let guestMatrixClient: Jotai.Atom.t<
  _,
  Jotai.Atom.Actions.set<string>,
  _,
> = Jotai.Atom.makeComputed(({get}) => get(homeserverUrl)->Result.map(Matrix.createClient(_)))
let flows: Jotai.Atom.t<_, Jotai.Atom.Actions.set<unit>, _> = Jotai.Atom.makeComputedAsync(({
  get,
}) =>
  switch get(guestMatrixClient) {
  | Ok(client) => client->Matrix.Login.getFlows->PResult.mapError(err => [MatrixError(err)])
  | Error(_) as errorRes => Promise.resolve(errorRes)
  }
)
let sessionCounterState = Jotai.Atom.make(0)
let loginTokenState = Jotai.Atom.make(None)
let accessTokenFromStorage: Jotai.Atom.t<
  _,
  Jotai.Atom.Actions.set<unit>,
  _,
> = Jotai.Atom.makeComputedAsync(({get}) => {
  get(sessionCounterState)->ignore
  CrossSecureStore.getItem("accessToken")->PResult.mapError(err => [StorageError(err)])
})
let accessTokenFromLoginToken: Jotai.Atom.t<
  _,
  Jotai.Atom.Actions.set<unit>,
  _,
> = Jotai.Atom.makeComputedAsync(({get}) =>
  switch (get(loginTokenState), get(guestMatrixClient), get(Device.deviceId)) {
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
let accessToken: Jotai.Atom.t<_, Jotai.Atom.Actions.set<unit>, _> = Jotai.Atom.makeComputed(({
  get,
}) =>
  switch (get(accessTokenFromLoginToken), get(accessTokenFromStorage)) {
  | (Ok(fromLoginOpt), Ok(fromStorageOpt)) =>
    [fromLoginOpt, fromStorageOpt]->ArrayX.keepMap(v => v)->ArrayX.get(0)->Result.ok
  | (fromLoginRes, fromStorageRes) =>
    [fromLoginRes, fromStorageRes]
    ->ArrayX.map(Result.getErrorWithDefault(_, []))
    ->ArrayX.flatten
    ->Result.error
  }
)

let matrixClient: Jotai.Atom.t<_, Jotai.Atom.Actions.set<unit>, _> = Jotai.Atom.makeComputed(({
  get,
}) =>
  switch (get(accessToken), get(homeserverUrl)) {
  | (Ok(Some(token)), Ok(url)) =>
    Matrix.createClient(url, ~accessToken=token)->Option.some->Result.ok
  | (Ok(None), _) => None->Result.ok
  | (accessTokenRes, homeserverUrlRes) =>
    StateUtils.mergeResultErrors2(accessTokenRes, homeserverUrlRes)
  }
)

let currentUserId: Jotai.Atom.t<
  _,
  Jotai.Atom.Actions.set<unit>,
  _,
> = Jotai.Atom.makeComputedAsync(({get}) =>
  get(matrixClient)
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
          ->ArrayX.filter(error =>
            switch error {
            | MatrixError(UnknownToken(_)) => true
            | _ => false
            }
          )
          ->ArrayX.length > 0 =>
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
      ->ArrayX.map(({id, name}) =>
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

    let matrixClient = Jotai.React.useAtomValue(guestMatrixClient)
    let flows = Jotai.React.useAtomValue(flows)
    let setLoginTokenState = Jotai.React.useUpdateAtom(loginTokenState)

    React.useEffect1(() => {
      setLoginTokenState(_ => queryLoginToken)
      router->Router.replace("/")
      None
    }, [queryLoginToken])

    <ReactNative.SafeAreaView
      style={ReactNative.Style.viewStyle(~flex=1., ~backgroundColor=Colors.green, ())}>
      <View style={Style.viewStyle(~flex=1., ~justifyContent=#center, ())}>
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
          ->ArrayX.mapi((flow, idx) =>
            <Flow key={idx->Belt.Int.toString} flow redirectUrl matrixClient=client />
          )
          ->React.array
        | _ => <Text> {"Impossible de charger les flows"->React.string} </Text>
        }}
      </View>
      <View style={Style.viewStyle(~alignItems=#center, ~marginVertical=10.->Style.dp, ())}>
        <Version color="rgba(255, 255, 255, 0.2)" />
      </View>
    </ReactNative.SafeAreaView>
  }
}

include ReactNavigation.Stack.Make({
  type params = unit
})

@react.component
let make = (~children) => {
  let currentUserId = Jotai.React.useAtomValue(currentUserId)

  <Navigator screenOptions={_ => options(~headerShown=false, ())}>
    {switch currentUserId {
    | Ok(None) =>
      <ScreenWithCallback name="Authenticate"> {_ => <Authenticate />} </ScreenWithCallback>
    | Ok(Some(_)) => <ScreenWithCallback name="Home"> {_ => children} </ScreenWithCallback>
    | _ => <Text> {"OOPS"->React.string} </Text>
    }}
  </Navigator>
}
