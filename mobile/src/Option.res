include Belt.Option

let some = a => Some(a)

let tap = (opt, fn) => {
  opt->Belt.Option.map(v => {
    fn(v)
    v
  })
}

let or = (a, b) => a->mapWithDefault(b, v => v->Some)
