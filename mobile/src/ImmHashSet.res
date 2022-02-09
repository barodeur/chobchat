let add = (set, val) => {
  if set->Belt.HashSet.has(val) {
    set
  } else {
    let new = set->Belt.HashSet.copy
    new->Belt.HashSet.add(val)
    new
  }
}
