type errItem =
  | MissingConfig
  | MatrixError(Matrix.err)
  | DeviceError(Device.err)
  | StorageError(CrossSecureStore.err)
type err = array<errItem>

let mergeResultErrors2 = (resA, resB) =>
  [resA->Result.getErrorWithDefault([]), resB->Result.getErrorWithDefault([])]
  ->Belt.Array.concatMany
  ->Result.error

let createConfigValue = (key, configSelector) =>
  Recoil.selector({
    key: key,
    get: ({get}) =>
      get(Config.recoilAtom)->Option.mapWithDefault(Error([MissingConfig]), config =>
        config->configSelector->Ok
      ),
  })

let homeserverUrl = createConfigValue("Config/homeserverUrl", config => config.homeserverUrl)
let roomId = createConfigValue("Config/roomId", config => config.roomId)

let guestMatrixClient = Recoil.selector({
  key: "MatixClient/Guest",
  get: ({get}) => get(homeserverUrl)->Result.map(Matrix.createClient(_)),
})
let flows = Recoil.asyncSelector({
  key: "Flows",
  get: ({get}) =>
    switch get(guestMatrixClient) {
    | Ok(client) => client->Matrix.Login.getFlows->PResult.mapError(err => [MatrixError(err)])
    | Error(_) as errorRes => Promise.resolve(errorRes)
    },
})
let sessionCounterState = Recoil.atom({key: "SessionCounterState", default: 0})
let loginTokenState = Recoil.atom({key: "LoginToken", default: None})
let accessTokenFromStorage = Recoil.asyncSelector({
  key: "AccessToken/FromStorage",
  get: ({get}) => {
    let _ = get(sessionCounterState)
    CrossSecureStore.getItem("accessToken")->PResult.mapError(err => [StorageError(err)])
  },
})
let accessTokenFromLoginToken = Recoil.asyncSelector({
  key: "AccessToken/FromLoginToken",
  get: ({get}) =>
    switch (get(loginTokenState), get(guestMatrixClient), get(Device.deviceId)) {
    | (Some(token), Ok(client), Ok(deviceId)) =>
      client
      ->Matrix.Login.loginWithToken({token: token, deviceId: Some(deviceId)})
      ->PResult.map(payload => Some(payload.accessToken))
      ->PResult.mapError(err => [MatrixError(err)])
    | (None, Ok(_), Ok(_)) => Promise.resolve(Ok(None))
    | (_, matrixClientRes, deviceIdRes) =>
      mergeResultErrors2(
        matrixClientRes,
        deviceIdRes->Result.mapError(err => [DeviceError(err)]),
      )->Promise.resolve
    },
})
let accessToken = Recoil.selector({
  key: "AccessToken",
  get: ({get}) => {
    switch Recoil.waitForAll2((accessTokenFromLoginToken, accessTokenFromStorage))->get {
    | (Ok(fromLoginOpt), Ok(fromStorageOpt)) =>
      [fromLoginOpt, fromStorageOpt]->Belt.Array.keepMap(v => v)->Belt.Array.get(0)->Result.ok
    | (fromLoginRes, fromStorageRes) =>
      [fromLoginRes, fromStorageRes]
      ->Belt.Array.map(Result.getErrorWithDefault(_, []))
      ->Belt.Array.concatMany
      ->Result.error
    }
  },
})
let matrixClient = Recoil.selector({
  key: "MatrixClient",
  get: ({get}) => {
    switch (get(accessToken), get(homeserverUrl)) {
    | (Ok(Some(token)), Ok(url)) =>
      Matrix.createClient(url, ~accessToken=token)->Option.some->Result.ok
    | (Ok(None), _) => None->Result.ok
    | (accessTokenRes, homeserverUrlRes) => mergeResultErrors2(accessTokenRes, homeserverUrlRes)
    }
  },
})
let currentUserId = Recoil.asyncSelector({
  key: "CurrentUserId",
  get: ({get}) => {
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
  },
})
let roomEventsState: Recoil.atomFamily<
  string,
  Recoil.t<array<Matrix.RoomEvent.t>, _>,
> = Recoil.atomFamily({
  key: "RoomEvents/State",
  default: _ => [],
})
let syncObservable = Recoil.selector({
  key: "SyncSubject",
  get: ({get}) =>
    switch (get(matrixClient), get(roomId)) {
    | (Ok(Some(client)), Ok(roomId)) =>
      client
      ->Matrix.createSyncObservable(
        ~filter=Matrix.Filter.t(~room=Matrix.Filter.roomFilter(~rooms=[roomId], ()), ()),
        (),
      )
      ->Rx.Observable.pipe(Rx.Operator.share())
      ->Some
      ->Ok
    | (Ok(None), _) => None->Ok
    | (matrixClientRes, mainRoomIdRes) => mergeResultErrors2(matrixClientRes, mainRoomIdRes)
    },
})

let useSync = roomId => {
  let obs = Recoil.useRecoilValue(syncObservable)
  let setRoomEvents = Recoil.useSetRecoilState(roomEventsState(roomId))

  React.useEffect3(() => {
    obs
    ->Result.map(
      Option.flatMap(_, obs => {
        let subscription = obs->Rx.Observable.subscribe(Rx.Observer.make(~next=e => {
            switch e {
            | Matrix.Event.RoomEvent((rId, roomEvent)) if rId == roomId =>
              setRoomEvents(events => events->Belt.Array.concat([roomEvent]))
            | _ => ()
            }
          }, ()))
        Some(() => subscription->Rx.Subscription.unsubscribe)
      }),
    )
    ->Result.getWithDefault(None)
  }, (obs, setRoomEvents, roomId))

  obs->Result.map(_ => ())
}
