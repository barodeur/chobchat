type id

@val external set: (unit => unit, int) => id = "setTimeout"
@val external clear: id => unit = "clearTimeout"
