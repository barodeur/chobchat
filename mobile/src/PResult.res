type t<'ok, 'error> = Promise.t<Belt.Result.t<'ok, 'error>>

let result: Promise.t<'a> => t<'a, 'error> = p =>
  p
  ->Promise.thenResolve(v => Result.Ok(v))
  ->Promise.catch(err => Result.Error(err)->Promise.resolve)

let map: (t<'a, 'error>, 'a => 'b) => t<'b, 'error> = (pres, fn) =>
  pres->Promise.thenResolve(Result.map(_, fn))

let flatMap: (t<'a, 'error>, 'a => t<'b, 'error>) => t<'b, 'error> = (pres, fn) => {
  pres->Promise.then(res =>
    switch res {
    | Error(err) => Promise.resolve(Error(err))
    | Ok(val) => fn(val)
    }
  )
}

let mapError: (t<'ok, 'a>, 'a => 'b) => t<'ok, 'b> = (pres, fn) =>
  pres->Promise.thenResolve(Result.mapError(_, fn))

let wrapPromise = res =>
  switch res {
  | Ok(promise) => promise
  | Error(err) => Promise.resolve(Error(err))
  }

let asyncTap = (pres, fn) =>
  pres->flatMap(v => {
    fn(v)->Promise.thenResolve(() => Ok(v))
  })

let tap = (pres, fn) =>
  pres->map(v => {
    fn(v)
    v
  })
