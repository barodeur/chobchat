include Belt.Result

let ok = v => Ok(v)
let error = v => Error(v)

let mapError = (res, fn) =>
  switch res {
  | Error(err) => Error(fn(err))
  | Ok(v) => Ok(v)
  }

let getErrorWithDefault = (res, default) =>
  switch res {
  | Error(err) => err
  | _ => default
  }

let tap = (opt, fn) => {
  opt->Belt.Result.map(v => {
    fn(v)
    v
  })
}
