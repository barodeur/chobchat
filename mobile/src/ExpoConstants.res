type extra = {commitSha: option<string>}
type manifest = {name: string, version: string, extra: extra}
type constants = {manifest: manifest}
@val @module("expo-constants") external constants: constants = "default"
