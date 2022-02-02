let joinedRooms = Jotai.Atom.make(Js.Dict.empty())

type user = {id: Matrix.UserId.t, name: option<string>}

type room = {
  id: Matrix.RoomId.t,
  name: option<string>,
  members: Dict.t<bool>,
  lastEventOriginServerTs: option<float>,
}
let rooms = Jotai.Atom.Family.make(
  id =>
    Jotai.Atom.make({id: id, name: None, members: Js.Dict.empty(), lastEventOriginServerTs: None}),
  Matrix.RoomId.equal,
)

let roomIdsBulastEventOriginServerTsDesc: Jotai.Atom.t<
  _,
  Jotai.Atom.Actions.set<unit>,
  _,
> = Jotai.Atom.makeComputed(({get}) => {
  get(joinedRooms)
  ->Js.Dict.entries
  ->Js.Array2.map(((roomId, _)) => get(rooms(roomId->Matrix.RoomId.fromString)))
  ->Js.Array2.sortInPlaceWith((roomA, roomB) =>
    switch roomB.lastEventOriginServerTs->Option.getWithDefault(0.) -.
      roomA.lastEventOriginServerTs->Option.getWithDefault(0.) {
    | v if v < 0. => -1
    | v if v > 0. => 1
    | _ => 0
    }
  )
  ->Js.Array2.map(({id}) => id)
})

let roomEvents = Jotai.Atom.Family.make(
  _ => Jotai.Atom.make(([]: array<Matrix.SyncRoomEvent.t>)),
  Matrix.RoomId.equal,
)

let syncAsyncIterator: Jotai.Atom.t<_, Jotai.Atom.Actions.set<unit>, _> = Jotai.Atom.makeComputed(({
  get,
}) => {
  switch (get(Authentication.matrixClient), Ok()) {
  | (Ok(Some(client)), Ok(_)) =>
    client
    ->Matrix.createSyncAsyncIterator(
      ~filter=Matrix.Filter.t(
        ~room=Matrix.Filter.Room.t(
          ~state=Matrix.Filter.State.t(~includeRedundantMembers=true, ()),
          (),
        ),
        (),
      ),
      (),
    )
    ->Some
    ->Ok
  | (Ok(None), _) => None->Ok
  | (matrixClientRes, mainRoomIdRes) =>
    StateUtils.mergeResultErrors2(matrixClientRes, mainRoomIdRes)
  }
})

let useSync = () => {
  let asyncIteratorRes = Jotai.React.useAtomValue(syncAsyncIterator)

  let touchRoom = Jotai.React.useAtomCallback(({set}, (roomId, timestamp)) => {
    let roomAtom = rooms(roomId)
    set(roomAtom, v => {
      ...v,
      lastEventOriginServerTs: Some(
        Js.Math.max_float(v.lastEventOriginServerTs->Belt.Option.getWithDefault(0.), timestamp),
      ),
    })
  })

  let processPayload = Jotai.React.useAtomCallback(({get, set}, payload: Matrix.Sync.Payload.t) => {
    payload.rooms->Option.mapWithDefault((), payloadRooms =>
      payloadRooms.join
      ->Js.Dict.entries
      ->Js.Array2.forEach(((roomId, room)) => {
        let roomId = Matrix.RoomId.fromString(roomId)
        let joinedRoomsValue = get(joinedRooms)
        let roomAtom = rooms(roomId)
        if !(joinedRoomsValue->Dict.has(roomId->Matrix.RoomId.toString)) {
          set(joinedRooms, joinedRoomsValue->Dict.add(roomId->Matrix.RoomId.toString, true))
        }

        room.state.events->Js.Array2.forEach(event => {
          touchRoom((roomId, event.originServerTs))->ignore
          switch event.content {
          | Name({name}) => set(roomAtom, v => {...v, name: Some(name)})
          | Member(_) =>
            set(roomAtom, v => {
              ...v,
              members: v.members->Dict.add(event.sender->Matrix.UserId.toString, true),
            })
          | _ => ()
          }
          ()
        })

        room.timeline.events->Js.Array2.forEach(event => {
          set(roomEvents(roomId), events => events->Js.Array2.concat([event]))
          touchRoom((roomId, event.originServerTs))->ignore
          switch event.content {
          | Name({name}) => set(roomAtom, v => {...v, name: Some(name)})
          | Member(_) =>
            set(roomAtom, v => {
              ...v,
              members: v.members->Dict.add(event.sender->Matrix.UserId.toString, true),
            })
          | _ => ()
          }
        })
      })
    )
  })

  React.useEffect1(() => {
    asyncIteratorRes
    ->Result.map(
      Option.flatMap(
        _,

        // switch payload {
        // | RoomEvent(rId, roomEvent) => addEvent((rId, roomEvent))->ignore
        // }
        // loop()
        asyncIterator => {
          let canceledRef = ref(false)
          let rec loop = () =>
            asyncIterator.next()
            ->Promise.thenResolve(payloadOpt => {
              payloadOpt
              ->Option.map(res =>
                res->Belt.Result.mapWithDefault((), payload => processPayload(payload)->ignore)
              )
              ->ignore
              loop()
            })
            ->ignore

          loop()

          Some(() => canceledRef.contents = true)
        },
      ),
    )
    ->Result.getWithDefault(None)
  }, [asyncIteratorRes])

  asyncIteratorRes->Result.map(_ => ())
}
