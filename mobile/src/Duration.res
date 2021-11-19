type t = Ms(int)

let ms: int => t = ms => Ms(ms)
let s: int => t = x => ms(x * 1000)
let m: int => t = x => s(x * 60)
let h: int => t = x => m(x * 60)
let d: int => t = x => h(x * 24)
