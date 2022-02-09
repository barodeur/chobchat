let joinedRooms = Jotai.Atom.make(Belt.HashSet.make(~id=module(Matrix.RoomId.Id), ~hintSize=100))

type user = {id: Matrix.UserId.t, name: option<string>}

type roomProperty<'value> = Jotai.Atom.Family.t<
  Matrix.RoomId.t,
  'value,
  Jotai.Atom.Actions.set<'value>,
  [Jotai.Atom.Tags.p | Jotai.Atom.Tags.w | Jotai.Atom.Tags.r],
>
let makeRoomProperty: 'value => roomProperty<'value> = initialValue =>
  Jotai.Atom.Family.make(_ => Jotai.Atom.make(initialValue), Matrix.RoomId.equal)
let roomName = makeRoomProperty((None: option<string>))
let roomLastEventOriginServerTs = makeRoomProperty(None)
let roomMembers = makeRoomProperty(Belt.HashSet.make(~id=module(Matrix.UserId.Id), ~hintSize=100))
let roomLastFullyReadEventId = makeRoomProperty((None: option<Matrix.EventId.t>))
let roomEventIds = makeRoomProperty(([]: array<Matrix.EventId.t>))
let roomTitle: Jotai.Atom.Family.t<
  _,
  _,
  Jotai.Atom.Actions.set<string>,
  _,
> = Jotai.Atom.Family.make(
  roomId =>
    Jotai.Atom.makeComputed(({get}) =>
      get(roomName(roomId))
      ->Option.or(
        get(Authentication.currentUserId)->Result.mapWithDefault(None, currentUserIdOpt =>
          currentUserIdOpt->Option.flatMap(currentUserId =>
            get(roomMembers(roomId))
            ->Belt.HashSet.toArray
            ->ArrayX.find(userId => currentUserId != userId)
            ->Option.map(Matrix.UserId.toString)
          )
        ),
      )
      ->Option.getWithDefault(roomId->Matrix.RoomId.toString)
    ),
  Matrix.RoomId.equal,
)

type eventProperty<'value> = Jotai.Atom.Family.t<
  Matrix.EventId.t,
  'value,
  Jotai.Atom.Actions.set<'value>,
  [Jotai.Atom.Tags.p | Jotai.Atom.Tags.w | Jotai.Atom.Tags.r],
>
let makeEventProperty: 'value => eventProperty<'value> = initialValue =>
  Jotai.Atom.Family.make(_ => Jotai.Atom.make(initialValue), Matrix.EventId.equal)
let event: Jotai.Atom.Family.t<
  Matrix.EventId.t,
  option<Matrix.SyncRoomEvent.t>,
  Jotai.Atom.Actions.set<option<Matrix.SyncRoomEvent.t>>,
  _,
> = Jotai.Atom.Family.make(_ => Jotai.Atom.make(None), Matrix.EventId.equal)
let eventRoomId = makeEventProperty((None: option<Matrix.RoomId.t>))
let eventIndex = Jotai.Atom.Family.make(
  (eventId): Jotai.Atom.t<_, Jotai.Atom.Actions.set<option<int>>, _> =>
    Jotai.Atom.makeComputed(({get}) =>
      get(eventRoomId(eventId))->Option.map(roomId =>
        get(roomEventIds(roomId))->ArrayX.findIndex(id => id == eventId)
      )
    ),
  Matrix.EventId.equal,
)
let eventIsRead = Jotai.Atom.Family.make(
  (eventId): Jotai.Atom.t<_, Jotai.Atom.Actions.set<bool>, _> =>
    Jotai.Atom.makeComputed(({get}) => {
      get(eventIndex(eventId))
      ->Option.flatMap(idx => {
        get(eventRoomId(eventId))
        ->Option.flatMap(roomId => get(roomLastFullyReadEventId(roomId)))
        ->Option.flatMap(lastFullyReadEventId => get(eventIndex(lastFullyReadEventId)))
        ->Option.map(lastFullyReadEventIndex => lastFullyReadEventIndex >= idx)
      })
      ->Option.getWithDefault(false)
    }),
  Matrix.EventId.equal,
)

let roomIdsBylastEventOriginServerTsDesc: Jotai.Atom.t<
  _,
  Jotai.Atom.Actions.set<unit>,
  _,
> = Jotai.Atom.makeComputed(({get}) => {
  get(joinedRooms)
  ->Belt.HashSet.toArray
  ->ArrayX.sortInPlaceWith((roomA, roomB) =>
    switch get(roomLastEventOriginServerTs(roomB))->Option.getWithDefault(0.) -.
      get(roomLastEventOriginServerTs(roomA))->Option.getWithDefault(0.) {
    | v if v < 0. => -1
    | v if v > 0. => 1
    | _ => 0
    }
  )
})

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
    set(roomLastEventOriginServerTs(roomId), v => {
      Some(Js.Math.max_float(v->Belt.Option.getWithDefault(0.), timestamp))
    })
  })

  let processPayload = Jotai.React.useAtomCallback(({set}, payload: Matrix.Sync.Payload.t) => {
    payload.rooms->Option.mapWithDefault((), payloadRooms =>
      payloadRooms.join
      ->Belt.HashMap.toArray
      ->ArrayX.forEach(((roomId, room)) => {
        set(joinedRooms, v => v->ImmHashSet.add(roomId))

        room.accountData.events->ArrayX.forEach(event => {
          switch event.content {
          | FullyRead({eventId}) => set(roomLastFullyReadEventId(roomId), _ => Some(eventId))
          | _ => ()
          }
        })

        room.state.events->ArrayX.forEach(event => {
          set(eventRoomId(event.eventId), _ => roomId)
          touchRoom((roomId, event.originServerTs))->ignore
          switch event.content {
          | Name({name}) => set(roomName(roomId), _ => Some(name))
          | Member(_) =>
            set(roomMembers(roomId), v => {
              v->ImmHashSet.add(event.sender)
            })
          | _ => ()
          }
          ()
        })

        room.timeline.events->ArrayX.forEach(e => {
          set(eventRoomId(e.eventId), _ => roomId)
          set(event(e.eventId), _ => Some(e))
          set(roomEventIds(roomId), ids => ids->ArrayX.concat([e.eventId]))
          touchRoom((roomId, e.originServerTs))->ignore
          switch e.content {
          | Name({name}) => set(roomName(roomId), _ => Some(name))
          | Member(_) =>
            set(roomMembers(roomId), v => {
              v->ImmHashSet.add(e.sender)
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
      Option.flatMap(_, asyncIterator => {
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
      }),
    )
    ->Result.getWithDefault(None)
  }, [asyncIteratorRes])

  asyncIteratorRes->Result.map(_ => ())
}
